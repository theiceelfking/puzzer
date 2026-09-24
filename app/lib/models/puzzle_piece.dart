class PuzzlePiece {
  final String id;
  final int row;
  final int col;
  double x;
  double y;
  bool placed;
  int z;

  PuzzlePiece({
    required this.id,
    required this.row,
    required this.col,
    required this.x,
    required this.y,
    required this.placed,
    required this.z,
  });

  factory PuzzlePiece.fromJson(Map<String, dynamic> json) {
    return PuzzlePiece(
      id: json['id'] as String,
      row: json['row'] as int,
      col: json['col'] as int,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      placed: json['placed'] as bool? ?? false,
      z: json['z'] as int? ?? 0,
    );
  }
}
