import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../api_service.dart';

/// Lightweight WebSocket client for doctor-patient direct chat presence:
/// live "typing" indicator, instant new-message push, and message-deletion
/// notifications.
///
/// Reconnects with exponential backoff so a dropped connection (network
/// blip, app backgrounded, backend restart) recovers automatically instead
/// of silently degrading forever — mirrors
/// HealthVaultWeb/src/utils/chatSocketClient.js against the same backend
/// endpoint.
class ChatSocketService {
  ChatSocketService({required this.onEvent});

  final void Function(Map<String, dynamic> event) onEvent;

  static const List<Duration> _reconnectDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 15),
  ];

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _manuallyClosed = false;

  Future<void> connect() async {
    _manuallyClosed = false;
    await _openSocket();
  }

  Future<void> _openSocket() async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) return;

    final wsBase = ApiService.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsBase/sessions/chat/ws?token=$token');

    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _subscription = channel.stream.listen(
        (raw) {
          _reconnectAttempt = 0;
          try {
            final event = jsonDecode(raw.toString()) as Map<String, dynamic>;
            onEvent(event);
          } catch (_) {
            // Ignore malformed frames.
          }
        },
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_manuallyClosed) return;
    if (_reconnectTimer != null) return;
    final delay = _reconnectDelays[
        _reconnectAttempt.clamp(0, _reconnectDelays.length - 1)];
    _reconnectAttempt += 1;
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      _openSocket();
    });
  }

  void sendTyping(String counterpartId) {
    _send({'type': 'typing', 'counterpartId': counterpartId});
  }

  void sendTypingStop(String counterpartId) {
    _send({'type': 'typing_stop', 'counterpartId': counterpartId});
  }

  void _send(Map<String, dynamic> payload) {
    try {
      _channel?.sink.add(jsonEncode(payload));
    } catch (_) {
      // Socket may already be closed; ignore — typing signals are
      // best-effort and not queued/retried.
    }
  }

  void dispose() {
    _manuallyClosed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _channel?.sink.close();
  }
}
