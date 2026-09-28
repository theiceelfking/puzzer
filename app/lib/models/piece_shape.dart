import 'dart:ui';

/// How far a tab sticks out past the piece's square cell, as a fraction of
/// the piece size. Widgets pad their bounds by this much on every side.
const double kTabRatio = 0.25;

/// Edge types for the four sides of a piece: 0 = flat (board border),
/// 1 = tab sticking out, -1 = blank (hole) cut in.
class PieceEdges {
  final int top;
  final int right;
  final int bottom;
  final int left;

  const PieceEdges(this.top, this.right, this.bottom, this.left);

  @override
  bool operator ==(Object other) =>
      other is PieceEdges && other.top == top && other.right == right && other.bottom == bottom && other.left == left;

  @override
  int get hashCode => Object.hash(top, right, bottom, left);

  /// Derives edges deterministically from [seed] (the room id) so every
  /// client in a room builds the same interlocking shapes without the
  /// server having to send them. Neighbouring pieces always get opposite
  /// signs on their shared side.
  factory PieceEdges.forPiece({
    required String seed,
    required int row,
    required int col,
    required int rows,
    required int cols,
  }) {
    // _sign(kind, r, c) is the edge type as seen from piece (r, c) for its
    // bottom (kind 0) or right (kind 1) side; the neighbour sees the inverse.
    final top = row == 0 ? 0 : -_sign(seed, 0, row - 1, col);
    final bottom = row == rows - 1 ? 0 : _sign(seed, 0, row, col);
    final left = col == 0 ? 0 : -_sign(seed, 1, row, col - 1);
    final right = col == cols - 1 ? 0 : _sign(seed, 1, row, col);
    return PieceEdges(top, right, bottom, left);
  }

  static int _sign(String seed, int kind, int row, int col) {
    // FNV-1a: stable across platforms (unlike String.hashCode on web vs VM).
    var h = 0x811c9dc5;
    for (final unit in '$seed:$kind:$row:$col'.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return (h >> 7) & 1 == 0 ? 1 : -1;
  }
}

// One edge running from (0, 0) to (1, 0), with the tab bulging towards +h.
// Each entry is a cubic segment: control1, control2, end (as (t, h) pairs).
const List<List<double>> _tabCurve = [
  [0.40, 0.00, 0.42, 0.05, 0.38, 0.10],
  [0.32, 0.18, 0.40, 0.24, 0.50, 0.24],
  [0.60, 0.24, 0.68, 0.18, 0.62, 0.10],
  [0.58, 0.05, 0.60, 0.00, 0.66, 0.00],
];

/// Builds the outline of a piece whose square cell spans
/// [origin, origin + size] and whose tabs may extend [kTabRatio] * size
/// beyond it.
Path buildPiecePath(PieceEdges edges, double size, Offset origin) {
  final path = Path()..moveTo(origin.dx, origin.dy);

  // Maps an edge-local (t, h) to canvas space for each side, walking the
  // square clockwise; h always points away from the piece's centre.
  Offset top(double t, double h) => origin + Offset(t * size, -h * size);
  Offset right(double t, double h) => origin + Offset(size + h * size, t * size);
  Offset bottom(double t, double h) => origin + Offset(size - t * size, size + h * size);
  Offset left(double t, double h) => origin + Offset(-h * size, size - t * size);

  void side(int type, Offset Function(double t, double h) map) {
    if (type != 0) {
      final start = map(0.34, 0);
      path.lineTo(start.dx, start.dy);
      for (final s in _tabCurve) {
        final c1 = map(s[0], s[1] * type);
        final c2 = map(s[2], s[3] * type);
        final end = map(s[4], s[5] * type);
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
      }
    }
    final end = map(1, 0);
    path.lineTo(end.dx, end.dy);
  }

  side(edges.top, top);
  side(edges.right, right);
  side(edges.bottom, bottom);
  side(edges.left, left);
  return path..close();
}
