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

  const b = connect();
  await new Promise((r) => b.on('open', r));
  b.send(JSON.stringify({ type: 'join_room', payload: { roomId: stateA.roomId, playerName: 'Bob' } }));
  await once(b, 'room_state');
  await once(a, 'player_joined');

  const piece = stateA.pieces[0];

  // Alice grabs it first
  const pickedByOthersPromise = once(b, 'piece_picked');
  a.send(JSON.stringify({ type: 'pick_piece', payload: { pieceId: piece.id } }));
  const pickedEvt = await pickedByOthersPromise;
  console.log('Bob sees piece_picked, heldBy:', pickedEvt.heldBy, '(expected Alice-ish id)');

  // Bob tries to grab the SAME piece while Alice holds it -> should be rejected
  const rejectedPromise = once(b, 'pick_rejected');
  b.send(JSON.stringify({ type: 'pick_piece', payload: { pieceId: piece.id } }));
  const rejected = await rejectedPromise;
  console.log('Bob pick_rejected for pieceId:', rejected.pieceId, '(expected', piece.id, ')');

  // Bob tries to move/drop the piece he doesn't hold -> server must ignore silently (no piece_moved/piece_placed for his attempt)
  let sawUnexpectedMove = false;
  b.send(JSON.stringify({ type: 'move_piece', payload: { pieceId: piece.id, x: 999, y: 999 } }));
  a.once('message', (raw) => {
    const msg = JSON.parse(raw.toString());
    if (msg.type === 'piece_moved' && msg.payload.x === 999) sawUnexpectedMove = true;
  });
  await new Promise((r) => setTimeout(r, 300));
  console.log('Bob move while not holding -> ignored:', !sawUnexpectedMove, '(expected true)');

  // Alice drops it -> hold released, heldBy null in the broadcast
  const placedPromise = once(b, 'piece_placed');
  a.send(JSON.stringify({ type: 'drop_piece', payload: { pieceId: piece.id, x: piece.x + 5, y: piece.y + 5 } }));
  const placed = await placedPromise;
  console.log('After Alice drops -> heldBy:', placed.heldBy, '(expected null)');

  // Now Bob CAN pick it up
  const pickedNowPromise = once(a, 'piece_picked');
  b.send(JSON.stringify({ type: 'pick_piece', payload: { pieceId: piece.id } }));
  const pickedNow = await pickedNowPromise;
  console.log('Bob now holds it, heldBy:', pickedNow.heldBy, '(expected Bobs id)');

  // Disconnecting Bob while he holds a piece should release it for everyone else
  const releasedPromise = once(a, 'piece_released');
  b.close();
  const released = await releasedPromise;
  console.log('piece_released after Bob disconnects, pieceId:', released.pieceId, '(expected', piece.id, ')');

  a.close();
  process.exit(0);
}

main().catch((err) => {
  console.error('TEST FAILED:', err);
  process.exit(1);
});
