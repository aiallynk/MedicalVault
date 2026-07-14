import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../services/chat_socket_service.dart';
import '../utils/timezone_utils.dart';
import '../widgets/ai_thinking_indicator.dart';

class DirectChatScreen extends StatefulWidget {
  final String counterpartId;
  final String counterpartName;
  final String counterpartRole;
  final String? counterpartAvatarUrl;
  final String? sessionId;

  const DirectChatScreen({
    super.key,
    required this.counterpartId,
    required this.counterpartName,
    required this.counterpartRole,
    this.counterpartAvatarUrl,
    this.sessionId,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  static const String _patientRole = "patient";
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _pollTimer;
  Timer? _typingStopTimer;
  bool _loading = true;
  bool _sending = false;
  bool _counterpartTyping = false;
  String? _error;
  List<Map<String, dynamic>> _messages = [];
  late final ChatSocketService _socket;

  @override
  void initState() {
    super.initState();
    _socket = ChatSocketService(onEvent: _handleSocketEvent);
    _socket.connect();
    _composerController.addListener(_onComposerChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _typingStopTimer?.cancel();
    _composerController.removeListener(_onComposerChanged);
    _composerController.dispose();
    _scrollController.dispose();
    _socket.dispose();
    super.dispose();
  }

  void _handleSocketEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final type = event['type']?.toString();
    if (type == 'typing') {
      setState(() => _counterpartTyping = true);
    } else if (type == 'typing_stop') {
      setState(() => _counterpartTyping = false);
    } else if (type == 'new_message') {
      _loadMessages(silent: true);
    }
  }

  void _onComposerChanged() {
    _socket.sendTyping(widget.counterpartId);
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(seconds: 2), () {
      _socket.sendTypingStop(widget.counterpartId);
    });
  }

  Future<void> _bootstrap() async {
    await _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _loadMessages(silent: true);
    });
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final messages = await ApiService.fetchChatMessages(widget.counterpartId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _composerController.text.trim();
    if (text.isEmpty || _sending) return;

    _typingStopTimer?.cancel();
    _socket.sendTypingStop(widget.counterpartId);

    final tempId = "temp_${DateTime.now().millisecondsSinceEpoch}";
    final optimistic = <String, dynamic>{
      "id": tempId,
      "senderRole": _patientRole,
      "message": text,
      "createdAt": nowForContextTimeZone(context).toIso8601String(),
      "pending": true,
    };

    setState(() {
      _sending = true;
      _messages = [..._messages, optimistic];
      _composerController.clear();
      _error = null;
    });
    _scrollToBottom();

    try {
      final response = await ApiService.sendDirectMessage(
        counterpartId: widget.counterpartId,
        message: text,
        sessionId: widget.sessionId,
      );
      if (!mounted) return;

      if (response?["success"] == true) {
        final rawChatMessage =
            response != null ? response["chatMessage"] : null;
        final chatMessage = rawChatMessage is Map
            ? rawChatMessage.map(
                (key, value) => MapEntry(key.toString(), value),
              )
            : null;
        setState(() {
          if (chatMessage != null) {
            _messages = _messages
                .map((entry) => entry["id"] == tempId
                    ? {
                        ...entry,
                        ...chatMessage,
                        "pending": false,
                      }
                    : entry)
                .toList();
          } else {
            _messages = _messages
                .where((entry) => entry["id"] != tempId)
                .toList(growable: false);
          }
        });
      } else {
        setState(() {
          _messages = _messages
              .where((entry) => entry["id"] != tempId)
              .toList(growable: false);
          _error = response?["message"]?.toString() ?? "Failed to send message";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .where((entry) => entry["id"] != tempId)
            .toList(growable: false);
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatMessageTime(dynamic raw) {
    return formatTimeForContext(
      context,
      raw,
      pattern: 'h:mm a',
      fallback: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = "Doctor chat";
    final displayNameRaw = widget.counterpartName.trim();
    final displayName = displayNameRaw.isEmpty
        ? "Doctor"
        : displayNameRaw.toLowerCase().startsWith("dr.")
            ? displayNameRaw
            : "Dr. $displayNameRaw";
    final avatarUrl =
        ApiService.resolveMediaUrl(widget.counterpartAvatarUrl) ?? "";

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage:
                  avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty
                  ? const Icon(Icons.medical_services_rounded, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text("No messages yet. Start the conversation."),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                        itemCount:
                            _messages.length + (_counterpartTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_counterpartTyping &&
                              index == _messages.length) {
                            return const TypingDotsBubble();
                          }
                          final message = _messages[index];
                          final senderRole = (message["senderRole"] ?? "")
                              .toString()
                              .trim()
                              .toLowerCase();
                          final isMine = senderRole == _patientRole;
                          final pending = message["pending"] == true;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: isMine
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isMine) ...[
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundImage: avatarUrl.isNotEmpty
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    child: avatarUrl.isEmpty
                                        ? const Icon(
                                            Icons.medical_services_rounded,
                                            size: 14,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    constraints:
                                        const BoxConstraints(maxWidth: 320),
                                    decoration: BoxDecoration(
                                      color: isMine
                                          ? theme.colorScheme.primary
                                          : theme
                                              .colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(18),
                                        topRight: const Radius.circular(18),
                                        bottomLeft:
                                            Radius.circular(isMine ? 18 : 4),
                                        bottomRight:
                                            Radius.circular(isMine ? 4 : 18),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (message["message"] ?? "").toString(),
                                          style: TextStyle(
                                            color: isMine
                                                ? theme.colorScheme.onPrimary
                                                : theme
                                                    .textTheme.bodyMedium?.color,
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "${_formatMessageTime(message["createdAt"])}${pending ? " - sending..." : ""}",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isMine
                                                ? theme.colorScheme.onPrimary
                                                    .withValues(alpha: 0.7)
                                                : theme
                                                    .textTheme.bodySmall?.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composerController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _sendMessage,
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
