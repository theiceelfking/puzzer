import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final image = kPuzzleImages.firstWhere((o) => o.id == _selectedImageId);
    final difficulties = image.difficulties;
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
            children: kPuzzleImages.map((option) {
              final selected = option.id == _selectedImageId;
              return GestureDetector(
                onTap: () => setState(() => _selectedImageId = option.id),
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
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Image.asset(
                            option.assetPath,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            // Decode thumbnails small; the full pictures are large.
                            cacheWidth: 480,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(option.label,
                            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
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
                          imageId: _selectedImageId,
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
