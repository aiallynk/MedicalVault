import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../utils/timezone_utils.dart';

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
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
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
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final senderRole = (message["senderRole"] ?? "")
                              .toString()
                              .trim()
                              .toLowerCase();
                          final isMine = senderRole == _patientRole;
                          final pending = message["pending"] == true;

                          return Align(
                            alignment: isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 9),
                              constraints: const BoxConstraints(maxWidth: 320),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (message["message"] ?? "").toString(),
                                    style: TextStyle(
                                      color: isMine
                                          ? Colors.white
                                          : Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${_formatMessageTime(message["createdAt"])}${pending ? " - sending..." : ""}",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMine
                                          ? Colors.white70
                                          : Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color,
                                    ),
                                  ),
                                ],
                              ),
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
