const WebSocket = require('ws');

function connect() {
  return new WebSocket('ws://localhost:8080');
}

function once(ws, type) {
  return new Promise((resolve) => {
    function handler(raw) {
      const msg = JSON.parse(raw.toString());
      if (msg.type === type) {
        ws.off('message', handler);
        resolve(msg.payload);
      }
    }
    ws.on('message', handler);
  });
}

async function main() {
  const a = connect();
  await new Promise((r) => a.on('open', r));

  a.send(JSON.stringify({ type: 'create_room', payload: { playerName: 'Alice', imageId: 'sunset', rows: 2, cols: 2 } }));
  const stateA = await once(a, 'room_state');
  console.log('Room created:', stateA.roomId, 'pieces:', stateA.pieces.length, 'you:', stateA.you);

  const b = connect();
  await new Promise((r) => b.on('open', r));
  b.send(JSON.stringify({ type: 'join_room', payload: { roomId: stateA.roomId, playerName: 'Bob' } }));

  const [stateB, joinedEvt] = await Promise.all([once(b, 'room_state'), once(a, 'player_joined')]);
  console.log('Bob joined, players seen by Bob:', stateB.players.map((p) => p.name));
  console.log('Alice saw player_joined:', joinedEvt.player.name);

  // pieceSize is shared with clients; correct position = col*pieceSize, row*pieceSize
  const correctPos = (p) => ({ x: p.col * stateB.pieceSize, y: p.row * stateB.pieceSize });

  // Bob must hold a piece before he's allowed to move/drop it
  const piece = stateB.pieces[0];
  b.send(JSON.stringify({ type: 'pick_piece', payload: { pieceId: piece.id } }));

  // Bob drops it far from home -> should NOT lock
  const farPromise = once(a, 'piece_placed');
  b.send(JSON.stringify({ type: 'drop_piece', payload: { pieceId: piece.id, x: piece.x + 5, y: piece.y + 5 } }));
  const farResult = await farPromise;
  console.log('Drop far from home -> placed:', farResult.placed, '(expected false)');

  // Bob picks it up again and drops exactly on its correct spot -> should lock
  b.send(JSON.stringify({ type: 'pick_piece', payload: { pieceId: piece.id } }));
  const exactPromise = once(a, 'piece_placed');
  const home = correctPos(piece);
  b.send(JSON.stringify({ type: 'drop_piece', payload: { pieceId: piece.id, x: home.x, y: home.y } }));
  const exactResult = await exactPromise;
  console.log('Drop on correct spot -> placed:', exactResult.placed, '(expected true)');

  // Complete the rest of the pieces (2x2 = 4 pieces total) and expect puzzle_completed
  const completedPromise = once(a, 'puzzle_completed');
  for (const p of stateB.pieces.slice(1)) {
    const pos = correctPos(p);
    b.send(JSON.stringify({ type: 'pick_piece', payload: { pieceId: p.id } }));
    b.send(JSON.stringify({ type: 'drop_piece', payload: { pieceId: p.id, x: pos.x, y: pos.y } }));
  }
  await completedPromise;
  console.log('puzzle_completed event received -> OK');

  a.close();
  b.close();
  process.exit(0);
}

main().catch((err) => {
  console.error('TEST FAILED:', err);
  process.exit(1);
});
