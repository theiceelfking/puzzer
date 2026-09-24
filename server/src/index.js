const http = require('http');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');
const { RoomManager } = require('./rooms');

const PORT = process.env.PORT || 8080;
const MIN_GRID = 2;
const MAX_GRID = 14;
const PLAYER_NAME_MAX = 24;

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

const wss = new WebSocketServer({ server });

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
      currentRoom.removePlayer(player.id);
      currentRoom.broadcast({ type: 'player_left', payload: { playerId: player.id } });
    }
    currentRoom = null;
  }

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
        const room = roomManager.createRoom(imageId, rows, cols);
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
        room.broadcast(
          { type: 'player_joined', payload: { player: { id: player.id, name: player.name, color: player.color } } },
          player.id,
        );
        break;
      }

      case 'pick_piece': {
        if (!currentRoom || !player) return;
        const piece = currentRoom.bringToFront(payload.pieceId);
        if (piece) {
          currentRoom.broadcast({ type: 'piece_picked', payload: { pieceId: piece.id, z: piece.z, by: player.id } }, player.id);
        }
        break;
      }

      case 'move_piece': {
        if (!currentRoom || !player) return;
        const { pieceId, x, y } = payload;
        if (typeof x !== 'number' || typeof y !== 'number') return;
        const piece = currentRoom.movePiece(pieceId, x, y);
        if (piece) {
          currentRoom.broadcast({ type: 'piece_moved', payload: { pieceId: piece.id, x: piece.x, y: piece.y, by: player.id } }, player.id);
        }
        break;
      }

      case 'drop_piece': {
        if (!currentRoom || !player) return;
        const { pieceId, x, y } = payload;
        if (typeof x !== 'number' || typeof y !== 'number') return;
        const piece = currentRoom.dropPiece(pieceId, x, y);
        if (piece) {
          currentRoom.broadcast({
            type: 'piece_placed',
            payload: { pieceId: piece.id, x: piece.x, y: piece.y, placed: piece.placed, z: piece.z, by: player.id },
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

      default:
        send(socket, 'error', { message: `Unknown message type: ${type}` });
    }
  });

  socket.on('close', () => {
    leaveCurrentRoom();
  });
});

server.listen(PORT, () => {
  console.log(`Puzzer WebSocket server listening on port ${PORT}`);
});
