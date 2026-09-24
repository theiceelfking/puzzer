import 'package:flutter/material.dart';

class PuzzlePlayer {
  final String id;
  final String name;
  final Color color;

  PuzzlePlayer({required this.id, required this.name, required this.color});

  factory PuzzlePlayer.fromJson(Map<String, dynamic> json) {
    return PuzzlePlayer(
      id: json['id'] as String,
      name: json['name'] as String,
      color: _parseHexColor(json['color'] as String? ?? '#4ECDC4'),
    );
  }

  static Color _parseHexColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}
