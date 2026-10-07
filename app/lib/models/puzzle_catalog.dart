class PuzzleImageOption {
  final String id;
  final String label;
  final String assetPath;

  /// Grid sizes offered for this picture; they follow its aspect ratio.
  final List<PuzzleDifficulty> difficulties;

  const PuzzleImageOption({
    required this.id,
    required this.label,
    required this.assetPath,
    this.difficulties = kPuzzleDifficulties,
  });
}

class PuzzleDifficulty {
  final String label;
  final int rows;
  final int cols;

  const PuzzleDifficulty({required this.label, required this.rows, required this.cols});

  int get pieceCount => rows * cols;
}

/// Grids for 4:3 pictures.
const List<PuzzleDifficulty> kPuzzleDifficulties = [
  PuzzleDifficulty(label: 'Dễ', rows: 3, cols: 4),
  PuzzleDifficulty(label: 'Trung bình', rows: 6, cols: 8),
  PuzzleDifficulty(label: 'Khó', rows: 9, cols: 12),
];

/// Grids for 3:2 pictures.
const List<PuzzleDifficulty> kThreeTwoDifficulties = [
  PuzzleDifficulty(label: 'Dễ', rows: 4, cols: 6),
  PuzzleDifficulty(label: 'Trung bình', rows: 6, cols: 9),
  PuzzleDifficulty(label: 'Khó', rows: 8, cols: 12),
];

/// Grids for 16:9 wallpapers. The server caps a side at 14 pieces, so these
/// only approximate 16:9; the board crops the picture slightly to fit.
const List<PuzzleDifficulty> kWideDifficulties = [
  PuzzleDifficulty(label: 'Dễ', rows: 3, cols: 5),
  PuzzleDifficulty(label: 'Trung bình', rows: 5, cols: 9),
  PuzzleDifficulty(label: 'Khó', rows: 8, cols: 14),
];

// The paintings are public-domain scans from Wikimedia Commons. Their ratios
// are only close to 4:3 or 3:2; the board crops the edges slightly to fit.
const List<PuzzleImageOption> kPuzzleImages = [
  PuzzleImageOption(id: 'starry_night', label: 'Đêm đầy sao', assetPath: 'assets/images/starry_night.jpg'),
  PuzzleImageOption(
    id: 'netherlandish_proverbs',
    label: 'Tục ngữ Hà Lan',
    assetPath: 'assets/images/netherlandish_proverbs.jpg',
    difficulties: kThreeTwoDifficulties,
  ),
  PuzzleImageOption(
    id: 'hunters_in_the_snow',
    label: 'Thợ săn trong tuyết',
    assetPath: 'assets/images/hunters_in_the_snow.jpg',
    difficulties: kThreeTwoDifficulties,
  ),
  PuzzleImageOption(
    id: 'grande_jatte',
    label: 'Chiều Chủ nhật trên đảo',
    assetPath: 'assets/images/grande_jatte.jpg',
    difficulties: kThreeTwoDifficulties,
  ),
  PuzzleImageOption(id: 'boating_party', label: 'Bữa trưa trên thuyền', assetPath: 'assets/images/boating_party.jpg'),
  PuzzleImageOption(id: 'moulin_galette', label: 'Moulin de la Galette', assetPath: 'assets/images/moulin_galette.jpg'),
  PuzzleImageOption(id: 'wheat_cypresses', label: 'Lúa mì và cây bách', assetPath: 'assets/images/wheat_cypresses.jpg'),
  PuzzleImageOption(id: 'tiger_storm', label: 'Hổ trong bão nhiệt đới', assetPath: 'assets/images/tiger_storm.jpg'),
  PuzzleImageOption(id: 'teniers_gallery', label: 'Phòng tranh hoàng gia', assetPath: 'assets/images/teniers_gallery.jpg'),
  PuzzleImageOption(
    id: 'peasant_wedding',
    label: 'Đám cưới nông dân',
    assetPath: 'assets/images/peasant_wedding.jpg',
    difficulties: kThreeTwoDifficulties,
  ),
];

/// Asset path for a room's picture id. Unknown ids (e.g. a room created by a
/// newer app version) fall back to the original PNG naming.
String puzzleAssetPath(String imageId) {
  for (final option in kPuzzleImages) {
    if (option.id == imageId) return option.assetPath;
  }
  return 'assets/images/$imageId.png';
}
