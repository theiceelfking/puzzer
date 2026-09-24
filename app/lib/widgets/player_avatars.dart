import 'package:flutter/material.dart';

import '../models/puzzle_player.dart';

class PlayerAvatars extends StatelessWidget {
  final List<PuzzlePlayer> players;
  final String? youId;

  const PlayerAvatars({super.key, required this.players, required this.youId});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: players.map((p) {
        final initial = p.name.isNotEmpty ? p.name[0].toUpperCase() : '?';
        return Tooltip(
          message: p.id == youId ? '${p.name} (bạn)' : p.name,
          child: CircleAvatar(
            radius: 14,
            backgroundColor: p.color,
            child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        );
      }).toList(),
    );
  }
}
