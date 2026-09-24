const { PIECE_SIZE, SNAP_TOLERANCE, generatePieces } = require('./puzzle');

const ROOM_CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O/0/I/1
const EMPTY_ROOM_TTL_MS = 5 * 60 * 1000;
const STALE_HOLD_MS = 10 * 1000; // a held piece can be stolen if not refreshed this long

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

  getPiece(pieceId) {
    return this.pieces.find((p) => p.id === pieceId) || null;
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
        id: p.id, row: p.row, col: p.col, x: p.x, y: p.y, placed: p.placed, z: p.z, heldBy: p.heldBy,
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

  /** True if `playerId` is allowed to act on this piece right now. */
  _isHeldByOther(piece, playerId) {
    if (!piece.heldBy || piece.heldBy === playerId) return false;
    return Date.now() - piece.heldAt < STALE_HOLD_MS;
  }

  /** Claims a piece for `playerId`, stealing a stale (abandoned) hold if needed. */
  holdPiece(pieceId, playerId) {
    const piece = this.pieces.find((p) => p.id === pieceId);
    if (!piece || piece.placed) return null;
    if (this._isHeldByOther(piece, playerId)) return null;
    piece.heldBy = playerId;
    piece.heldAt = Date.now();
    piece.z = this.zCounter++;
    return piece;
  }

  /** Moves a piece during an active drag. Only the current holder may move it. */
  movePiece(pieceId, x, y, playerId) {
    const piece = this.pieces.find((p) => p.id === pieceId);
    if (!piece || piece.placed) return null;
    if (piece.heldBy !== playerId) return null;
    piece.heldAt = Date.now();
    piece.x = x;
    piece.y = y;
    return piece;
  }

  /** Drops a piece; snaps + locks it if close enough to its home. Releases the hold either way. */
  dropPiece(pieceId, x, y, playerId) {
    const piece = this.pieces.find((p) => p.id === pieceId);
    if (!piece || piece.placed) return null;
    if (piece.heldBy !== playerId) return null;

    piece.heldBy = null;
    piece.heldAt = 0;

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

  /** Releases any pieces held by a player who disconnected mid-drag. Returns the freed pieces. */
  releasePiecesHeldBy(playerId) {
    const released = [];
    for (const piece of this.pieces) {
      if (piece.heldBy === playerId) {
        piece.heldBy = null;
        piece.heldAt = 0;
        released.push(piece);
      }
    }
    return released;
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
