const http = require('http');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');
const { RoomManager } = require('./rooms');

const PORT = process.env.PORT || 8080;
const MIN_GRID = 2;
const MAX_GRID = 14;
const PLAYER_NAME_MAX = 24;
// Proxies such as Cloudflare drop WebSockets that stay silent for ~100s, so
// ping every client well inside that window. A client that doesn't answer
// by the next round is considered gone.
const HEARTBEAT_MS = 30 * 1000;
// Uploaded pictures arrive base64-encoded inside create_room. The app shrinks
// them first, so this (~1.5 MB of JPEG) is a ceiling against abuse.
const CUSTOM_IMAGE_ID = 'custom';
const MAX_IMAGE_BASE64 = 2 * 1024 * 1024;
const MAX_MESSAGE_BYTES = MAX_IMAGE_BASE64 + 64 * 1024;

const roomManager = new RoomManager();

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ ok: true, rooms: roomManager.rooms.size }));
    return;
  }
  res.writeHead(404);
  res.end();
});

const wss = new WebSocketServer({ server, maxPayload: MAX_MESSAGE_BYTES });

function send(socket, type, payload) {
  if (socket.readyState === socket.OPEN) {
    socket.send(JSON.stringify({ type, payload }));
  }
}

function sanitizeName(name) {
  const trimmed = String(name || '').trim().slice(0, PLAYER_NAME_MAX);
  return trimmed || 'Guest';
}

function clampGrid(n) {
  const v = Math.round(Number(n));
  if (!Number.isFinite(v)) return MIN_GRID;
  return Math.min(MAX_GRID, Math.max(MIN_GRID, v));
}

wss.on('connection', (socket) => {
  let currentRoom = null;
  let player = null;

  function leaveCurrentRoom() {
    if (currentRoom && player) {
      const released = currentRoom.releasePiecesHeldBy(player.id);
      for (const piece of released) {
        currentRoom.broadcast({ type: 'piece_released', payload: { pieceId: piece.id } });
      }
      currentRoom.removePlayer(player.id);
      currentRoom.broadcast({ type: 'player_left', payload: { playerId: player.id } });
    }
    currentRoom = null;
  }

  socket.isAlive = true;
  socket.on('pong', () => {
    socket.isAlive = true;
  });

  socket.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      send(socket, 'error', { message: 'Invalid message format' });
      return;
    }

    const { type, payload = {} } = msg;

    switch (type) {
      case 'create_room': {
        const imageId = String(payload.imageId || '').trim();
        if (!imageId) {
          send(socket, 'error', { message: 'imageId is required' });
          return;
        }
        const rows = clampGrid(payload.rows ?? 4);
        const cols = clampGrid(payload.cols ?? 4);

        leaveCurrentRoom();
        // Defaults to on, so clients that don't send it keep the old look.
        const showBackground = payload.showBackground !== false;
        let imageData = null;
        if (imageId === CUSTOM_IMAGE_ID) {
          imageData = payload.imageData;
          if (typeof imageData !== 'string' || imageData.length === 0) {
            send(socket, 'error', { message: 'imageData is required' });
            return;
          }
          if (imageData.length > MAX_IMAGE_BASE64) {
            send(socket, 'error', { message: 'Image too large' });
            return;
          }
        }
        const room = roomManager.createRoom(imageId, rows, cols, showBackground, imageData);
        player = {
          id: crypto.randomUUID(),
          name: sanitizeName(payload.playerName),
          color: roomManager.nextPlayerColor(room),
          socket,
        };
        room.addPlayer(player);
        currentRoom = room;

        send(socket, 'room_state', room.publicState(player.id));
        break;
      }

      case 'join_room': {
        const room = roomManager.get(payload.roomId);
        if (!room) {
          send(socket, 'error', { message: 'Room not found' });
          return;
        }
        leaveCurrentRoom();
        player = {
          id: crypto.randomUUID(),
          name: sanitizeName(payload.playerName),
          color: roomManager.nextPlayerColor(room),
          socket,
        };
        room.addPlayer(player);
        currentRoom = room;

        send(socket, 'room_state', room.publicState(player.id));
        // A client rejoining after a dropped connection already has it.
        if (room.imageData !== null && payload.haveImage !== true) {
          send(socket, 'room_image', { data: room.imageData });
        }
        room.broadcast(
          { type: 'player_joined', payload: { player: { id: player.id, name: player.name, color: player.color } } },
          player.id,
        );
        break;
      }

      case 'pick_piece': {
        if (!currentRoom || !player) return;
        const piece = currentRoom.holdPiece(payload.pieceId, player.id);
        if (piece) {
          currentRoom.broadcast(
            { type: 'piece_picked', payload: { pieceId: piece.id, z: piece.z, heldBy: piece.heldBy, by: player.id } },
            player.id,
          );
        } else {
          // Someone else already holds it (or it's placed) - tell the requester
          // so their optimistic local drag can be cancelled.
          const current = currentRoom.getPiece(payload.pieceId);
          send(socket, 'pick_rejected', { pieceId: payload.pieceId, heldBy: current?.heldBy ?? null });
        }
        break;
      }

      case 'move_piece': {
        if (!currentRoom || !player) return;
        const { pieceId, x, y } = payload;
        if (typeof x !== 'number' || typeof y !== 'number') return;
        const piece = currentRoom.movePiece(pieceId, x, y, player.id);
        if (piece) {
          currentRoom.broadcast({ type: 'piece_moved', payload: { pieceId: piece.id, x: piece.x, y: piece.y, by: player.id } }, player.id);
        }
        break;
      }

      case 'drop_piece': {
        if (!currentRoom || !player) return;
        const { pieceId, x, y } = payload;
        if (typeof x !== 'number' || typeof y !== 'number') return;
        const piece = currentRoom.dropPiece(pieceId, x, y, player.id);
        if (piece) {
          currentRoom.broadcast({
            type: 'piece_placed',
            payload: { pieceId: piece.id, x: piece.x, y: piece.y, placed: piece.placed, z: piece.z, heldBy: piece.heldBy, by: player.id },
          });
          if (currentRoom.completed) {
            currentRoom.broadcast({ type: 'puzzle_completed', payload: {} });
          }
        }
        break;
      }

      case 'leave_room': {
        leaveCurrentRoom();
        break;
      }

      // Keepalive sent by the app; the reply is only there to carry traffic.
      case 'ping': {
        send(socket, 'pong', {});
        break;
      }

      default:
        send(socket, 'error', { message: `Unknown message type: ${type}` });
    }
  });

  // Without a listener, a socket error (an oversized or malformed frame, a
  // reset connection) is thrown and takes the whole server down. ws closes
  // the socket itself, and 'close' below does the cleanup.
  socket.on('error', () => {});

  socket.on('close', () => {
    leaveCurrentRoom();
  });
});

setInterval(() => {
  for (const socket of wss.clients) {
    if (!socket.isAlive) {
      socket.terminate();
      continue;
    }
    socket.isAlive = false;
    socket.ping();
  }
}, HEARTBEAT_MS).unref();

server.listen(PORT, () => {
  console.log(`Puzzer WebSocket server listening on port ${PORT}`);
});
