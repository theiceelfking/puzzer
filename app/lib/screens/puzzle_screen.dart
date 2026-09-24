import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../services/game_service.dart';
import '../widgets/player_avatars.dart';
import '../widgets/puzzle_board.dart';

class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  ui.Image? _image;
  String? _loadedImageId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final imageId = context.read<GameService>().imageId;
    if (imageId.isNotEmpty && imageId != _loadedImageId) {
      _loadedImageId = imageId;
      _loadImage(imageId);
    }
  }

  Future<void> _loadImage(String imageId) async {
    final data = await rootBundle.load('assets/images/$imageId.png');
    final bytes = Uint8List.view(data.buffer, data.offsetInBytes, data.lengthInBytes);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _image = frame.image);
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameService>();
    final image = _image;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave(context);
        if (leave && context.mounted) {
          await context.read<GameService>().leaveRoom();
          if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Text('Phòng ${game.roomId ?? ''}'),
              const SizedBox(width: 12),
              Expanded(child: PlayerAvatars(players: game.players.values.toList(), youId: game.youId)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Rời phòng',
              onPressed: () async {
                final leave = await _confirmLeave(context);
                if (leave && context.mounted) {
                  await context.read<GameService>().leaveRoom();
                  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                }
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: LinearProgressIndicator(
              value: game.pieces.isEmpty ? 0 : game.placedCount / game.pieces.length,
              minHeight: 6,
            ),
          ),
        ),
        body: image == null
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: Theme.of(context).canvasColor, child: PuzzleBoard(image: image))),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Card(
                      color: Colors.black54,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text(
                          '${game.placedCount}/${game.pieces.length} mảnh',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  if (game.completed) _CompletionOverlay(imageId: game.imageId),
                ],
              ),
      ),
    );
  }

  Future<bool> _confirmLeave(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rời phòng?'),
        content: const Text('Bạn sẽ ngắt kết nối khỏi phòng ghép hình này.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rời phòng')),
        ],
      ),
    );
    return result ?? false;
  }
}

class _CompletionOverlay extends StatelessWidget {
  final String imageId;

  const _CompletionOverlay({required this.imageId});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.celebration, size: 48, color: Colors.amber),
                  const SizedBox(height: 12),
                  const Text('Hoàn thành!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Cả nhóm đã ghép xong bức tranh 🎉', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/images/$imageId.png', width: 220),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      await context.read<GameService>().leaveRoom();
                      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    child: const Text('Về trang chủ'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
