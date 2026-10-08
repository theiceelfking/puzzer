import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/puzzle_piece.dart';
import '../models/puzzle_player.dart';

enum ConnectionStatus { disconnected, connecting, connected, reconnecting, error }

/// Proxies in front of the server (e.g. Cloudflare) drop WebSockets that stay
/// silent for ~100s, so send a keepalive well inside that window.
const Duration _kPingInterval = Duration(seconds: 25);
const int _kMaxReconnectAttempts = 6;

/// Holds the live state of one puzzle room and talks to the realtime
/// WebSocket server. All room state is authoritative on the server; this
/// class only renders what the server last told it (plus transient local
/// drag positions handled by the piece widgets themselves).
class GameService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  // Remembered so a dropped connection can rejoin the same room.
  String? _serverUrl;
  String? _playerName;

  ConnectionStatus status = ConnectionStatus.disconnected;
  String? errorMessage;

  String? roomId;
  String? youId;
  String imageId = '';
  int rows = 0;
  int cols = 0;
  double pieceSize = 100;
  bool completed = false;
  // Whether the faint picture is drawn under the board as a guide.
  bool showBackground = true;

  final List<PuzzlePiece> pieces = [];
  final Map<String, PuzzlePlayer> players = {};

  int get placedCount => pieces.where((p) => p.placed).length;

  Future<void> connectAndCreateRoom({
    required String serverUrl,
    required String playerName,
    required String imageId,
    required int rows,
    required int cols,
    bool showBackground = true,
  }) async {
    _playerName = playerName;
    await _connect(serverUrl);
    _send('create_room', {
      'playerName': playerName,
      'imageId': imageId,
      'rows': rows,
      'cols': cols,
      'showBackground': showBackground,
    });
  }

  Future<void> connectAndJoinRoom({
    required String serverUrl,
    required String playerName,
    required String roomId,
  }) async {
    _playerName = playerName;
    await _connect(serverUrl);
    _send('join_room', {
      'playerName': playerName,
      'roomId': roomId.trim().toUpperCase(),
    });
  }

  /// Opens the socket. With [rejoining] the current room state stays on
  /// screen (status [ConnectionStatus.reconnecting]) instead of being reset.
  Future<void> _connect(String serverUrl, {bool rejoining = false}) async {
    _serverUrl = serverUrl;
    _pingTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    if (!rejoining) {
      _reconnectTimer?.cancel();
      _reconnectAttempts = 0;
      _resetRoomState();
    }

    status = rejoining ? ConnectionStatus.reconnecting : ConnectionStatus.connecting;
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
      _pingTimer = Timer.periodic(_kPingInterval, (_) => _send('ping', {}));
      notifyListeners();
    } catch (e) {
      if (rejoining) rethrow; // _reconnect decides whether to try again
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
    showBackground = true;
    pieces.clear();
    players.clear();
  }

  void _onMessage(dynamic raw) {
    final Map<String, dynamic> msg = jsonDecode(raw as String) as Map<String, dynamic>;
    final String type = msg['type'] as String? ?? '';
    final Map<String, dynamic> payload = (msg['payload'] as Map?)?.cast<String, dynamic>() ?? {};

    switch (type) {
      case 'room_state':
        _reconnectAttempts = 0;
        status = ConnectionStatus.connected;
        _applyRoomState(payload);
        break;
      case 'pong':
        return;
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
        final message = payload['message'] as String?;
        // Servers that predate the keepalive answer it with this error.
        if (message != null && message.startsWith('Unknown message type: ping')) return;
        if (message == 'Room not found') {
          // Also reached when rejoining after a drop: the room is gone.
          errorMessage = 'Không tìm thấy phòng. Hãy kiểm tra lại mã phòng; phòng cũng có thể đã bị đóng.';
          _resetRoomState();
        } else {
          errorMessage = message;
        }
        // An error while we're not in a room means create/join failed. Flag
        // it so the UI shows the message instead of waiting forever.
        if (roomId == null) status = ConnectionStatus.error;
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
    showBackground = payload['showBackground'] as bool? ?? true;

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
    if (roomId != null) {
      _scheduleReconnect();
      return;
    }
    status = ConnectionStatus.error;
    errorMessage = 'Mất kết nối tới server: $error';
    notifyListeners();
  }

  void _onSocketDone() {
    if (roomId != null) {
      _scheduleReconnect();
      return;
    }
    if (status != ConnectionStatus.error) {
      status = ConnectionStatus.disconnected;
      notifyListeners();
    }
  }

  /// The socket dropped while we were in a room: keep the board on screen and
  /// try to get back in, backing off between attempts.
  void _scheduleReconnect() {
    _pingTimer?.cancel();
    if (_reconnectTimer?.isActive ?? false) return;
    if (_reconnectAttempts >= _kMaxReconnectAttempts) {
      _resetRoomState();
      status = ConnectionStatus.error;
      errorMessage = 'Mất kết nối tới server. Hãy kiểm tra mạng rồi vào lại phòng.';
      notifyListeners();
      return;
    }
    status = ConnectionStatus.reconnecting;
    notifyListeners();
    final delay = Duration(seconds: 1 << _reconnectAttempts.clamp(0, 4));
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, _reconnect);
  }

  Future<void> _reconnect() async {
    final url = _serverUrl;
    final room = roomId;
    if (url == null || room == null) return;
    try {
      await _connect(url, rejoining: true);
      _send('join_room', {'playerName': _playerName ?? '', 'roomId': room});
    } catch (_) {
      if (roomId != null) _scheduleReconnect();
    }
  }

  void pickPiece(String pieceId) => _send('pick_piece', {'pieceId': pieceId});

  void movePiece(String pieceId, double x, double y) =>
      _send('move_piece', {'pieceId': pieceId, 'x': x, 'y': y});

  void dropPiece(String pieceId, double x, double y) =>
      _send('drop_piece', {'pieceId': pieceId, 'x': x, 'y': y});

  void _send(String type, Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) return;
    if (status != ConnectionStatus.connected && status != ConnectionStatus.reconnecting) return;
    channel.sink.add(jsonEncode({'type': type, 'payload': payload}));
  }

  Future<void> leaveRoom() async {
    _send('leave_room', {});
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    status = ConnectionStatus.disconnected;
    _resetRoomState();
    notifyListeners();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
