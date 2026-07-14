import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../api_service.dart';

/// Lightweight WebSocket client for doctor-patient direct chat presence:
/// live "typing" indicator and instant new-message push.
class ChatSocketService {
  ChatSocketService({required this.onEvent});

  final void Function(Map<String, dynamic> event) onEvent;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  Future<void> connect() async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) return;

    final wsBase = ApiService.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsBase/sessions/chat/ws?token=$token');

    try {
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        (raw) {
          try {
            final event = jsonDecode(raw.toString()) as Map<String, dynamic>;
            onEvent(event);
          } catch (_) {
            // Ignore malformed frames.
          }
        },
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {
      // Connection failures fall back silently to HTTP polling.
    }
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
      // Socket may already be closed; ignore.
    }
  }

  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
  }
}
