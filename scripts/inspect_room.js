const WebSocket = require('ws');
const roomId = process.argv[2];
const ws = new WebSocket('ws://localhost:8080');
ws.on('open', () => {
  ws.send(JSON.stringify({ type: 'join_room', payload: { roomId, playerName: 'Inspector' } }));
});
ws.on('message', (raw) => {
  const msg = JSON.parse(raw.toString());
  if (msg.type === 'room_state') {
    console.log(`rows=${msg.payload.rows} cols=${msg.payload.cols} pieceSize=${msg.payload.pieceSize}`);
    const boardW = msg.payload.cols * msg.payload.pieceSize;
    const boardH = msg.payload.rows * msg.payload.pieceSize;
    console.log(`boardW=${boardW} boardH=${boardH}`);
    for (const p of msg.payload.pieces) {
      console.log(`${p.id} row=${p.row} col=${p.col} x=${p.x.toFixed(1)} y=${p.y.toFixed(1)} placed=${p.placed} z=${p.z}`);
    }
    process.exit(0);
  }
});
ws.on('error', (e) => { console.error('WS error', e); process.exit(1); });
setTimeout(() => { console.error('timeout'); process.exit(1); }, 5000);
