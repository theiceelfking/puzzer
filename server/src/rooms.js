const { PIECE_SIZE, SNAP_TOLERANCE, generatePieces } = require('./puzzle');

const ROOM_CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O/0/I/1
const EMPTY_ROOM_TTL_MS = 5 * 60 * 1000;

const PLAYER_COLORS = [
  '#FF6B6B', '#4ECDC4', '#FFD166', '#06D6A0',
  '#A78BFA', '#F472B6', '#60A5FA', '#F97316',
];

function makeRoomCode() {
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += ROOM_CODE_CHARS[Math.floor(Math.random() * ROOM_CODE_CHARS.length)];
  }
  return code;
}

class Room {
  constructor(id, imageId, rows, cols) {
    this.id = id;
    this.imageId = imageId;
    this.rows = rows;
    this.cols = cols;
    this.pieces = generatePieces(rows, cols);
    this.players = new Map(); // playerId -> { id, name, color, socket }
    this.zCounter = this.pieces.length + 1;
    this.emptySince = null;
    this.completed = false;
  }

  get pieceCount() {
    return this.pieces.length;
  }

  placedCount() {
    return this.pieces.filter((p) => p.placed).length;
  }

  addPlayer(player) {
    this.players.set(player.id, player);
    this.emptySince = null;
  }

  removePlayer(playerId) {
    this.players.delete(playerId);
    if (this.players.size === 0) {
      this.emptySince = Date.now();
    }
  }

  isStale() {
    return this.emptySince !== null && Date.now() - this.emptySince > EMPTY_ROOM_TTL_MS;
  }

  publicPlayers() {
    return [...this.players.values()].map((p) => ({ id: p.id, name: p.name, color: p.color }));
  }

  publicState(youId) {
    return {
      roomId: this.id,
      imageId: this.imageId,
      rows: this.rows,
      cols: this.cols,
      pieceSize: PIECE_SIZE,
      pieces: this.pieces.map((p) => ({
        id: p.id, row: p.row, col: p.col, x: p.x, y: p.y, placed: p.placed, z: p.z,
      })),
      players: this.publicPlayers(),
      completed: this.completed,
      you: youId,
    };
  }

  broadcast(message, excludePlayerId) {
    const data = JSON.stringify(message);
    for (const player of this.players.values()) {
      if (player.id === excludePlayerId) continue;
      if (player.socket.readyState === player.socket.OPEN) {
        player.socket.send(data);
      }
    }
  }

  /** Moves a piece during an active drag. Rejects if piece already locked. */
  movePiece(pieceId, x, y) {
    const piece = this.pieces.find((p) => p.id === pieceId);
    if (!piece || piece.placed) return null;
    piece.x = x;
    piece.y = y;
    return piece;
  }

  /** Drops a piece; snaps + locks it if close enough to its home. */
  dropPiece(pieceId, x, y) {
    const piece = this.pieces.find((p) => p.id === pieceId);
    if (!piece || piece.placed) return null;

    const dist = Math.hypot(x - piece.correctX, y - piece.correctY);
    if (dist <= SNAP_TOLERANCE) {
      piece.x = piece.correctX;
      piece.y = piece.correctY;
      piece.placed = true;
    } else {
      piece.x = x;
      piece.y = y;
      piece.z = this.zCounter++;
    }

    if (!this.completed && this.placedCount() === this.pieceCount) {
      this.completed = true;
    }

    return piece;
  }

  bringToFront(pieceId) {
    const piece = this.pieces.find((p) => p.id === pieceId);
    if (!piece || piece.placed) return null;
    piece.z = this.zCounter++;
    return piece;
  }
}

class RoomManager {
  constructor() {
    this.rooms = new Map();
    setInterval(() => this.sweepStaleRooms(), 60 * 1000).unref();
  }

  createRoom(imageId, rows, cols) {
    let id;
    do {
      id = makeRoomCode();
    } while (this.rooms.has(id));
    const room = new Room(id, imageId, rows, cols);
    this.rooms.set(id, room);
    return room;
  }

  get(id) {
    return this.rooms.get(id?.toUpperCase());
  }

  sweepStaleRooms() {
    for (const [id, room] of this.rooms) {
      if (room.isStale()) this.rooms.delete(id);
    }
  }

  nextPlayerColor(room) {
    const used = new Set([...room.players.values()].map((p) => p.color));
    return PLAYER_COLORS.find((c) => !used.has(c)) || PLAYER_COLORS[room.players.size % PLAYER_COLORS.length];
  }
}

module.exports = { RoomManager };
