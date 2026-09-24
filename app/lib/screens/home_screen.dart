import 'package:flutter/material.dart';

import 'create_room_screen.dart';
import 'join_room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nameController = TextEditingController();
  final _serverController = TextEditingController(text: 'ws://10.0.2.2:8080');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  bool _validate() => _formKey.currentState?.validate() ?? false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.extension, size: 64, color: Colors.deepPurple),
                    const SizedBox(height: 12),
                    Text(
                      'Puzzer',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Ghép hình cùng bạn bè theo thời gian thực',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Tên của bạn', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _serverController,
                      decoration: const InputDecoration(
                        labelText: 'Địa chỉ server',
                        hintText: 'ws://10.0.2.2:8080',
                        helperText: 'Máy ảo Android dùng 10.0.2.2. Thiết bị thật dùng IP LAN của máy chạy server.',
                        helperMaxLines: 2,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập địa chỉ server' : null,
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Tạo phòng mới'),
                      onPressed: () {
                        if (!_validate()) return;
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CreateRoomScreen(
                            playerName: _nameController.text.trim(),
                            serverUrl: _serverController.text.trim(),
                          ),
                        ));
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Tham gia phòng có sẵn'),
                      onPressed: () {
                        if (!_validate()) return;
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => JoinRoomScreen(
                            playerName: _nameController.text.trim(),
                            serverUrl: _serverController.text.trim(),
                          ),
                        ));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
