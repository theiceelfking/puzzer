import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/puzzle_piece.dart';
import '../models/puzzle_player.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

/// Holds the live state of one puzzle room and talks to the realtime
/// WebSocket server. All room state is authoritative on the server; this
/// class only renders what the server last told it (plus transient local
/// drag positions handled by the piece widgets themselves).
class GameService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  ConnectionStatus status = ConnectionStatus.disconnected;
  String? errorMessage;

  String? roomId;
  String? youId;
  String imageId = '';
  int rows = 0;
  int cols = 0;
  double pieceSize = 100;
  bool completed = false;

  final List<PuzzlePiece> pieces = [];
  final Map<String, PuzzlePlayer> players = {};

  int get placedCount => pieces.where((p) => p.placed).length;

  Future<void> connectAndCreateRoom({
    required String serverUrl,
    required String playerName,
    required String imageId,
    required int rows,
    required int cols,
  }) async {
    await _connect(serverUrl);
    _send('create_room', {
      'playerName': playerName,
      'imageId': imageId,
      'rows': rows,
      'cols': cols,
    });
  }

  Future<void> connectAndJoinRoom({
    required String serverUrl,
    required String playerName,
    required String roomId,
  }) async {
    await _connect(serverUrl);
    _send('join_room', {
      'playerName': playerName,
      'roomId': roomId.trim().toUpperCase(),
    });
  }

  Future<void> _connect(String serverUrl) async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _resetRoomState();

    status = ConnectionStatus.connecting;
    errorMessage = null;
    notifyListeners();

    try {
      final channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      await channel.ready;
      _channel = channel;
      status = ConnectionStatus.connected;
      _subscription = channel.stream.listen(
        _onMessage,
        onError: _onSocketError,
        onDone: _onSocketDone,
      );
      notifyListeners();
    } catch (e) {
      status = ConnectionStatus.error;
      errorMessage = 'Không thể kết nối tới server: $e';
      notifyListeners();
      rethrow;
    }
  }

  void _resetRoomState() {
    roomId = null;
    youId = null;
    imageId = '';
    rows = 0;
    cols = 0;
    completed = false;
    pieces.clear();
    players.clear();
  }

  void _onMessage(dynamic raw) {
    final Map<String, dynamic> msg = jsonDecode(raw as String) as Map<String, dynamic>;
    final String type = msg['type'] as String? ?? '';
    final Map<String, dynamic> payload = (msg['payload'] as Map?)?.cast<String, dynamic>() ?? {};

    switch (type) {
      case 'room_state':
        _applyRoomState(payload);
        break;
      case 'player_joined':
        final p = PuzzlePlayer.fromJson((payload['player'] as Map).cast<String, dynamic>());
        players[p.id] = p;
        break;
      case 'player_left':
        players.remove(payload['playerId']);
        break;
      case 'piece_picked':
        _updatePiece(payload['pieceId'] as String, (p) {
          p.z = payload['z'] as int? ?? p.z;
          p.heldBy = payload['heldBy'] as String?;
        });
        break;
      case 'pick_rejected':
        _updatePiece(payload['pieceId'] as String, (p) => p.heldBy = payload['heldBy'] as String?);
        break;
      case 'piece_released':
        _updatePiece(payload['pieceId'] as String, (p) => p.heldBy = null);
        break;
      case 'piece_moved':
        _updatePiece(payload['pieceId'] as String, (p) {
          p.x = (payload['x'] as num).toDouble();
          p.y = (payload['y'] as num).toDouble();
        });
        break;
      case 'piece_placed':
        _updatePiece(payload['pieceId'] as String, (p) {
          p.x = (payload['x'] as num).toDouble();
          p.y = (payload['y'] as num).toDouble();
          p.placed = payload['placed'] as bool? ?? p.placed;
          p.z = payload['z'] as int? ?? p.z;
          p.heldBy = payload['heldBy'] as String?;
        });
        break;
      case 'puzzle_completed':
        completed = true;
        break;
      case 'error':
        errorMessage = payload['message'] as String?;
        break;
    }
    notifyListeners();
  }

  void _applyRoomState(Map<String, dynamic> payload) {
    roomId = payload['roomId'] as String?;
    youId = payload['you'] as String?;
    imageId = payload['imageId'] as String? ?? '';
    rows = payload['rows'] as int? ?? 0;
    cols = payload['cols'] as int? ?? 0;
    pieceSize = (payload['pieceSize'] as num?)?.toDouble() ?? 100;
    completed = payload['completed'] as bool? ?? false;

    pieces
      ..clear()
      ..addAll((payload['pieces'] as List)
          .map((e) => PuzzlePiece.fromJson((e as Map).cast<String, dynamic>())));

    players.clear();
    for (final raw in (payload['players'] as List)) {
      final p = PuzzlePlayer.fromJson((raw as Map).cast<String, dynamic>());
      players[p.id] = p;
    }
  }

  void _updatePiece(String pieceId, void Function(PuzzlePiece piece) apply) {
    for (final piece in pieces) {
      if (piece.id == pieceId) {
        apply(piece);
        return;
      }
    }
  }

  void _onSocketError(Object error) {
    status = ConnectionStatus.error;
    errorMessage = 'Mất kết nối tới server: $error';
    notifyListeners();
  }

  void _onSocketDone() {
    if (status != ConnectionStatus.error) {
      status = ConnectionStatus.disconnected;
      notifyListeners();
    }
  }

  void pickPiece(String pieceId) => _send('pick_piece', {'pieceId': pieceId});

  void movePiece(String pieceId, double x, double y) =>
      _send('move_piece', {'pieceId': pieceId, 'x': x, 'y': y});

  void dropPiece(String pieceId, double x, double y) =>
      _send('drop_piece', {'pieceId': pieceId, 'x': x, 'y': y});

  void _send(String type, Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null || status != ConnectionStatus.connected) return;
    channel.sink.add(jsonEncode({'type': type, 'payload': payload}));
  }

  Future<void> leaveRoom() async {
    _send('leave_room', {});
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    status = ConnectionStatus.disconnected;
    _resetRoomState();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
