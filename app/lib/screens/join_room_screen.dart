import 'package:flutter/material.dart';

import 'game_screen.dart';

class JoinRoomScreen extends StatefulWidget {
  final String playerName;
  final String serverUrl;

  const JoinRoomScreen({super.key, required this.playerName, required this.serverUrl});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tham gia phòng')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Nhập mã phòng bạn bè đã chia sẻ'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Mã phòng',
                  hintText: 'VD: 8UKGA8',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập mã phòng' : null,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Tham gia'),
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => GameScreen(
                      connect: (service) => service.connectAndJoinRoom(
                        serverUrl: widget.serverUrl,
                        playerName: widget.playerName,
                        roomId: _codeController.text,
                      ),
                    ),
                  ));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
