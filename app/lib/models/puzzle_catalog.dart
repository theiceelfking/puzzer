class PuzzleImageOption {
  final String id;
  final String label;
  final String assetPath;

  const PuzzleImageOption({required this.id, required this.label, required this.assetPath});
}

class PuzzleDifficulty {
  final String label;
  final int rows;
  final int cols;

  const PuzzleDifficulty({required this.label, required this.rows, required this.cols});

  int get pieceCount => rows * cols;
}

/// Bundled sample pictures. Row/col counts below all keep the same 3:4
/// (height:width) ratio as the generated 800x600 images so pieces render
/// without stretching.
const List<PuzzleImageOption> kPuzzleImages = [
  PuzzleImageOption(id: 'sunset', label: 'Hoàng hôn', assetPath: 'assets/images/sunset.png'),
  PuzzleImageOption(id: 'ocean', label: 'Đại dương', assetPath: 'assets/images/ocean.png'),
  PuzzleImageOption(id: 'forest', label: 'Rừng cây', assetPath: 'assets/images/forest.png'),
  PuzzleImageOption(id: 'mountain', label: 'Núi non', assetPath: 'assets/images/mountain.png'),
];

const List<PuzzleDifficulty> kPuzzleDifficulties = [
  PuzzleDifficulty(label: 'Dễ', rows: 3, cols: 4),
  PuzzleDifficulty(label: 'Trung bình', rows: 6, cols: 8),
  PuzzleDifficulty(label: 'Khó', rows: 9, cols: 12),
];
