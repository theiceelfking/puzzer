import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/puzzle_catalog.dart';
import 'game_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  final String playerName;
  final String serverUrl;

  const CreateRoomScreen({super.key, required this.playerName, required this.serverUrl});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  String _selectedImageId = kPuzzleImages.first.id;
  int _difficultyIndex = 0;
  bool _showBackground = true;
  // The player's own picture, if they picked one. Kept in memory only: it is
  // never written to the device, and the server drops it with the room.
  Uint8List? _customBytes;
  double _customRatio = 4 / 3;
  bool _picking = false;

  // Raw size the server accepts once base64-encoded (see MAX_IMAGE_BASE64).
  static const int _maxCustomBytes = 1500 * 1024;

  Future<void> _pickCustomImage() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      // The picker shrinks and re-encodes the photo, so what we upload is a
      // modest JPEG rather than a full camera original.
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxCustomBytes) {
        _showMessage('Ảnh quá lớn. Hãy chọn ảnh khác.');
        return;
      }
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final ratio = frame.image.width / frame.image.height;
      frame.image.dispose();
      if (!mounted) return;
      setState(() {
        _customBytes = bytes;
        _customRatio = ratio;
        _selectedImageId = kCustomImageId;
        _difficultyIndex = 0;
      });
    } catch (_) {
      _showMessage('Không mở được ảnh này. Hãy thử ảnh khác.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _tileFrame({required bool selected, required Widget picture, required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
        child: Column(
          children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(9), child: picture)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customTile() {
    final bytes = _customBytes;
    final selected = _selectedImageId == kCustomImageId;
    if (bytes == null) {
      final scheme = Theme.of(context).colorScheme;
      return _tileFrame(
        selected: false,
        onTap: _pickCustomImage,
        label: 'Tải ảnh lên',
        picture: Container(
          width: double.infinity,
          color: scheme.surfaceContainerHighest,
          child: _picking
              ? const Center(child: CircularProgressIndicator())
              : Icon(Icons.add_photo_alternate_outlined, size: 44, color: scheme.primary),
        ),
      );
    }
    return _tileFrame(
      selected: selected,
      // First tap selects it; tapping the selected tile picks another photo.
      onTap: selected ? _pickCustomImage : () => setState(() => _selectedImageId = kCustomImageId),
      label: selected ? 'Chạm để đổi ảnh' : 'Ảnh của bạn',
      picture: Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, cacheWidth: 480),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usingCustom = _selectedImageId == kCustomImageId && _customBytes != null;
    final difficulties = usingCustom
        ? difficultiesForAspect(_customRatio)
        : kPuzzleImages.firstWhere((o) => o.id == _selectedImageId, orElse: () => kPuzzleImages.first).difficulties;
    final difficulty = difficulties[_difficultyIndex.clamp(0, difficulties.length - 1)];

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo phòng mới')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Chọn ảnh để ghép hình', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 4 / 3.6,
            children: [
              _customTile(),
              for (final option in kPuzzleImages)
                _tileFrame(
                  selected: option.id == _selectedImageId,
                  onTap: () => setState(() => _selectedImageId = option.id),
                  label: option.label,
                  picture: Image.asset(
                    option.assetPath,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    // Decode thumbnails small; the full pictures are large.
                    cacheWidth: 480,
                  ),
                ),
            ],
          ),
        ],
      ),
      // Pinned so the picture list can grow without pushing these off-screen.
      bottomNavigationBar: Material(
        elevation: 8,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Độ khó', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(difficulties.length, (i) {
                    final d = difficulties[i];
                    return ChoiceChip(
                      label: Text('${d.label} (${d.pieceCount} mảnh)'),
                      selected: difficulty == d,
                      onSelected: (_) => setState(() => _difficultyIndex = i),
                    );
                  }),
                ),
                CheckboxListTile(
                  value: _showBackground,
                  onChanged: (v) => setState(() => _showBackground = v ?? true),
                  title: const Text('Hiện nền ảnh'),
                  subtitle: const Text('Ảnh mờ bên dưới để dễ ghép hơn'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 4),
                FilledButton.icon(
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Tạo phòng'),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => GameScreen(
                        connect: (service) => service.connectAndCreateRoom(
                          serverUrl: widget.serverUrl,
                          playerName: widget.playerName,
                          imageId: usingCustom ? kCustomImageId : _selectedImageId,
                          customImage: usingCustom ? _customBytes : null,
                          rows: difficulty.rows,
                          cols: difficulty.cols,
                          showBackground: _showBackground,
                        ),
                      ),
                    ));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
