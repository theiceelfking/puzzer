const PIECE_SIZE = 100; // virtual units, client scales to fit screen
const SNAP_TOLERANCE = 28; // virtual units

function randRange(min, max) {
  return min + Math.random() * (max - min);
}

/**
 * Builds the initial piece set for a rows x cols jigsaw grid.
 * Pieces start scattered around a padded area so they don't all overlap
 * the board exactly, and no two pieces start pre-solved.
 */
function generatePieces(rows, cols) {
  const boardWidth = cols * PIECE_SIZE;
  const boardHeight = rows * PIECE_SIZE;
  const padX = boardWidth * 0.45;
  const padY = boardHeight * 0.45;

  const pieces = [];
  let id = 0;
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const correctX = c * PIECE_SIZE;
      const correctY = r * PIECE_SIZE;
      let x;
      let y;
      // keep scattering until the piece starts reasonably far from its home
      do {
        x = randRange(-padX, boardWidth + padX - PIECE_SIZE);
        y = randRange(-padY, boardHeight + padY - PIECE_SIZE);
      } while (Math.hypot(x - correctX, y - correctY) < PIECE_SIZE * 1.5);

      pieces.push({
        id: `p${id++}`,
        row: r,
        col: c,
        correctX,
        correctY,
        x,
        y,
        placed: false,
        z: id,
      });
    }
  }
  return pieces;
}

module.exports = { PIECE_SIZE, SNAP_TOLERANCE, generatePieces };
