import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/game_service.dart';
import 'puzzle_screen.dart';

/// Connects to the server (create or join, depending on [connect]) and
/// shows a loading / error state until the room_state arrives, then hands
/// off to the real puzzle UI.
class GameScreen extends StatefulWidget {
  final Future<void> Function(GameService service) connect;

  const GameScreen({super.key, required this.connect});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _connecting = false;

  Future<void> _start() async {
    if (_connecting) return;
    setState(() => _connecting = true);
    try {
      await widget.connect(context.read<GameService>());
    } catch (_) {
      // Surfaced via GameService.status/errorMessage; nothing else to do here.
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameService>(
      builder: (context, game, _) {
        if (game.roomId != null) return const PuzzleScreen();

        if (game.status == ConnectionStatus.error) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text(
                      game.errorMessage ?? 'Không thể kết nối tới server',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _connecting ? null : _start,
                      child: const Text('Thử lại'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Quay lại'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Đang kết nối tới phòng...'),
              ],
            ),
          ),
        );
      },
    );
  }
}
