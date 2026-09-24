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

  @override
  Widget build(BuildContext context) {
    final difficulty = kPuzzleDifficulties[_difficultyIndex];

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
                          child: Image.asset(option.assetPath, fit: BoxFit.cover, width: double.infinity),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(option.label),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('Độ khó', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(kPuzzleDifficulties.length, (i) {
              final d = kPuzzleDifficulties[i];
              return ChoiceChip(
                label: Text('${d.label} (${d.pieceCount} mảnh)'),
                selected: _difficultyIndex == i,
                onSelected: (_) => setState(() => _difficultyIndex = i),
              );
            }),
          ),
          const SizedBox(height: 32),
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
                  ),
                ),
              ));
            },
          ),
        ],
      ),
    );
  }
}
