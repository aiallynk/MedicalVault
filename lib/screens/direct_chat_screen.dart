import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../api_service.dart';
import '../services/chat_socket_service.dart';
import '../utils/chat_message_merge.dart';
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
  static const double _loadOlderTriggerOffset = 200;
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _pollTimer;
  Timer? _typingStopTimer;
  bool _loading = true;
  bool _sending = false;
  bool _counterpartTyping = false;
  bool _loadingOlder = false;
  bool _loadOlderFailed = false;
  bool _hasMoreOlder = false;
  String? _error;
  List<Map<String, dynamic>> _messages = [];
  late final ChatSocketService _socket;

  @override
  void initState() {
    super.initState();
    _socket = ChatSocketService(onEvent: _handleSocketEvent);
    _socket.connect();
    _composerController.addListener(_onComposerChanged);
    _scrollController.addListener(_handleScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _typingStopTimer?.cancel();
    _composerController.removeListener(_onComposerChanged);
    _composerController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _socket.dispose();
    super.dispose();
  }

  String _idOf(Map<String, dynamic> message) => (message['id'] ?? '').toString();

  void _handleScroll() {
    // This ListView runs top-to-bottom (oldest at index 0, newest at the
    // bottom, matching _scrollToBottom's target), so "scrolling up" toward
    // older messages moves toward pixels == 0, not maxScrollExtent.
    if (!_scrollController.hasClients) return;
    if (_loadingOlder || !_hasMoreOlder) return;
    if (_scrollController.position.pixels <= _loadOlderTriggerOffset) {
      _loadOlderMessages();
    }
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
    } else if (type == 'chat:message_deleted') {
      _applyRemoteMessageDeletion(event);
    }
  }

  /// Applies a `chat:message_deleted` event pushed from the other
  /// participant's delete-for-everyone action. Only ever touches local
  /// state for the message named in the event — never re-fetches, so it
  /// cannot disturb any optimistic/pending bubble mid-send.
  void _applyRemoteMessageDeletion(Map<String, dynamic> event) {
    final messageId = (event['messageId'] ?? '').toString();
    if (messageId.isEmpty) return;
    setState(() {
      _messages = _messages.map((entry) {
        if (_idOf(entry) != messageId) return entry;
        return {
          ...entry,
          'message': '',
          'isDeletedForEveryone': true,
        };
      }).toList(growable: false);
    });
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

  /// Cheap content signature for deciding whether a poll actually changed
  /// the visible conversation. Deliberately includes status fields
  /// (pending/failed) so a genuine state transition (e.g. sending -> sent)
  /// still triggers a rebuild, while an identical silent re-poll does not.
  String _messagesSignature(List<Map<String, dynamic>> messages) {
    final buffer = StringBuffer();
    for (final message in messages) {
      buffer
        ..write(message['id'])
        ..write('|')
        ..write(message['message'])
        ..write('|')
        ..write(message['pending'])
        ..write('|')
        ..write(message['failed'])
        ..write('|')
        ..write(message['readByRecipient'])
        ..write(';');
    }
    return buffer.toString();
  }

  /// Loads (or silently refreshes) the newest page of the conversation.
  /// Older pages previously loaded via [_loadOlderMessages] are preserved —
  /// only the tail (most-recent messages plus any local-only pending/failed
  /// bubbles) is subject to the merge/replace logic, so a background poll
  /// can never discard history the user scrolled up to see.
  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final page = await ApiService.fetchChatMessages(widget.counterpartId);
      if (!mounted) return;
      if (page['success'] != true) {
        if (!silent) {
          setState(() {
            _loading = false;
            _error = 'Failed to load messages';
          });
        }
        return;
      }
      final serverMessages =
          List<Map<String, dynamic>>.from(page['messages'] as List);
      final olderHistory = _messages
          .where((entry) => entry['pending'] != true && entry['failed'] != true)
          .toList(growable: false);
      final oldestServerId =
          serverMessages.isNotEmpty ? _idOf(serverMessages.first) : null;
      final priorOlderMessages = oldestServerId == null
          ? olderHistory
          : olderHistory
              .takeWhile((entry) => _idOf(entry) != oldestServerId)
              .toList(growable: false);

      final merged = mergeChatMessages(
        serverMessages: serverMessages,
        localMessages: _messages,
      );
      final fullList = [...priorOlderMessages, ...merged];
      final changed =
          _messagesSignature(fullList) != _messagesSignature(_messages);

      if (changed || _loading || _error != null) {
        setState(() {
          _messages = fullList;
          _hasMoreOlder = page['hasMore'] == true;
          _loading = false;
          _error = null;
        });
        // Only snap to the latest message when the conversation actually
        // changed — an identical silent re-poll must never yank the view
        // back to the bottom while the user is reading older messages.
        if (priorOlderMessages.isEmpty) _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  /// Fetches an older page (triggered by scrolling toward the top of the
  /// conversation) and prepends it. Preserves scroll position by measuring
  /// the scroll extent before and after the prepend and adjusting the
  /// offset by exactly the added height, so the message the user was
  /// looking at stays in the same place on screen.
  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || !_hasMoreOlder || _messages.isEmpty) return;
    final oldestId = _idOf(_messages.first);
    if (oldestId.isEmpty) return;

    setState(() {
      _loadingOlder = true;
      _loadOlderFailed = false;
    });

    final page = await ApiService.fetchChatMessages(
      widget.counterpartId,
      before: oldestId,
    );
    if (!mounted) return;

    if (page['success'] != true) {
      setState(() {
        _loadingOlder = false;
        _loadOlderFailed = true;
      });
      return;
    }

    final older = List<Map<String, dynamic>>.from(page['messages'] as List);
    final previousExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;

    setState(() {
      _messages = [...older, ..._messages];
      _hasMoreOlder = page['hasMore'] == true;
      _loadingOlder = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final newExtent = _scrollController.position.maxScrollExtent;
      final delta = newExtent - previousExtent;
      if (delta > 0) {
        _scrollController.jumpTo(_scrollController.position.pixels + delta);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _composerController.text.trim();
    if (text.isEmpty || _sending) return;

    _typingStopTimer?.cancel();
    _socket.sendTypingStop(widget.counterpartId);

    final tempId = "temp_${DateTime.now().millisecondsSinceEpoch}";
    final clientMessageId = const Uuid().v4();
    final optimistic = <String, dynamic>{
      "id": tempId,
      "clientMessageId": clientMessageId,
      "senderRole": _patientRole,
      "message": text,
      "createdAt": nowForContextTimeZone(context).toIso8601String(),
      "pending": true,
      "failed": false,
    };

    setState(() {
      _messages = [..._messages, optimistic];
      _composerController.clear();
      _error = null;
    });
    _scrollToBottom();

    await _dispatchOptimisticMessage(
      tempId: tempId,
      clientMessageId: clientMessageId,
      text: text,
    );
  }

  /// Retries a previously failed send using the SAME clientMessageId, so a
  /// retry after a network failure can never create a duplicate message
  /// server-side (the backend's unique index on
  /// doctorId+patientId+senderId+clientMessageId treats it as the same
  /// logical send).
  Future<void> _retryMessage(Map<String, dynamic> failedEntry) async {
    final tempId = (failedEntry["id"] ?? "").toString();
    final clientMessageId = (failedEntry["clientMessageId"] ?? "").toString();
    final text = (failedEntry["message"] ?? "").toString();
    if (tempId.isEmpty || clientMessageId.isEmpty || text.isEmpty) return;

    setState(() {
      _messages = _messages
          .map((entry) => entry["id"] == tempId
              ? {...entry, "pending": true, "failed": false}
              : entry)
          .toList(growable: false);
      _error = null;
    });

    await _dispatchOptimisticMessage(
      tempId: tempId,
      clientMessageId: clientMessageId,
      text: text,
    );
  }

  Future<void> _dispatchOptimisticMessage({
    required String tempId,
    required String clientMessageId,
    required String text,
  }) async {
    setState(() => _sending = true);

    try {
      final response = await ApiService.sendDirectMessage(
        counterpartId: widget.counterpartId,
        message: text,
        clientMessageId: clientMessageId,
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
            // Replace the optimistic entry in place — never remove then
            // re-add, which is what caused the visible disappear/reappear.
            _messages = _messages
                .map((entry) => entry["id"] == tempId
                    ? {
                        ...entry,
                        ...chatMessage,
                        "pending": false,
                        "failed": false,
                      }
                    : entry)
                .toList(growable: false);
          } else {
            _messages = _messages
                .map((entry) => entry["id"] == tempId
                    ? {...entry, "pending": false, "failed": false}
                    : entry)
                .toList(growable: false);
          }
        });
      } else {
        setState(() {
          // Keep the bubble visible — mark it failed rather than removing
          // it, so the user can tap to retry without retyping.
          _messages = _messages
              .map((entry) => entry["id"] == tempId
                  ? {...entry, "pending": false, "failed": true}
                  : entry)
              .toList(growable: false);
          _error = response?["message"]?.toString() ?? "Failed to send message";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .map((entry) => entry["id"] == tempId
                ? {...entry, "pending": false, "failed": true}
                : entry)
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

  Future<void> _confirmDeleteChat({required String mode}) async {
    final isEveryone = mode == 'everyone';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEveryone ? 'Delete for everyone?' : 'Delete chat?'),
        content: Text(
          isEveryone
              ? 'This will permanently delete this conversation for both you and the other person. This cannot be undone.'
              : 'This will remove the conversation from your chat list. The other person will still see it. It will reappear if a new message arrives.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: isEveryone
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  )
                : null,
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final success =
        await ApiService.deleteChatThread(widget.counterpartId, mode: mode);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete chat. Please try again.')),
      );
    }
  }

  Future<void> _showMessageActions(
    Map<String, dynamic> message, {
    required bool isMine,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Delete for me'),
              onTap: () => Navigator.of(sheetContext).pop('for-me'),
            ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded),
                title: const Text('Delete for everyone'),
                onTap: () => Navigator.of(sheetContext).pop('for-everyone'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    await _confirmDeleteMessage(message, scope: action);
  }

  Future<void> _confirmDeleteMessage(
    Map<String, dynamic> message, {
    required String scope,
  }) async {
    final isEveryone = scope == 'for-everyone';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEveryone ? 'Delete for everyone?' : 'Delete message?'),
        content: Text(
          isEveryone
              ? 'This message will be removed for both you and the other person. This cannot be undone.'
              : 'This message will be removed from your view only. The other person will still see it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: isEveryone
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  )
                : null,
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messageId = _idOf(message);
    if (messageId.isEmpty) return;

    final response = await ApiService.deleteChatMessage(messageId, scope: scope);
    if (!mounted) return;

    if (response['success'] != true) {
      final code = response['code']?.toString();
      final fallback = code == 'DELETE_WINDOW_EXPIRED'
          ? 'This message can no longer be deleted for everyone.'
          : response['message']?.toString() ?? 'Could not delete message.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(fallback)));
      return;
    }

    setState(() {
      if (scope == 'for-me') {
        _messages = _messages
            .where((entry) => _idOf(entry) != messageId)
            .toList(growable: false);
      } else {
        _messages = _messages.map((entry) {
          if (_idOf(entry) != messageId) return entry;
          return {...entry, 'message': '', 'isDeletedForEveryone': true};
        }).toList(growable: false);
      }
    });
  }

  Widget _buildLoadOlderHeader(ThemeData theme) {
    if (_loadingOlder) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_loadOlderFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: TextButton(
            onPressed: _loadOlderMessages,
            child: const Text('Could not load older messages — Retry'),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
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
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Chat options',
            onSelected: (mode) => _confirmDeleteChat(mode: mode),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'me', child: Text('Delete for me')),
              PopupMenuItem(value: 'everyone', child: Text('Delete for everyone')),
            ],
          ),
        ],
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
                        itemCount: 1 +
                            _messages.length +
                            (_counterpartTyping ? 1 : 0),
                        itemBuilder: (context, rawIndex) {
                          if (rawIndex == 0) {
                            return _buildLoadOlderHeader(theme);
                          }
                          final index = rawIndex - 1;
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
                          final failed = message["failed"] == true;
                          final deleted =
                              message["isDeletedForEveryone"] == true;

                          final bubbleMaxWidth = (MediaQuery.sizeOf(context).width * 0.78)
                              .clamp(220.0, 480.0);
                          final bubble = Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                            decoration: BoxDecoration(
                              color: failed
                                  ? theme.colorScheme.errorContainer
                                  : deleted
                                      ? theme.colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.5)
                                      : isMine
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme
                                              .surfaceContainerHighest,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isMine ? 18 : 4),
                                bottomRight: Radius.circular(isMine ? 4 : 18),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (deleted)
                                      Icon(
                                        Icons.block_rounded,
                                        size: 14,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    if (deleted) const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        deleted
                                            ? (isMine
                                                ? "You deleted this message"
                                                : "This message was deleted")
                                            : (message["message"] ?? "")
                                                .toString(),
                                        style: TextStyle(
                                          fontStyle: deleted
                                              ? FontStyle.italic
                                              : FontStyle.normal,
                                          color: failed
                                              ? theme.colorScheme.onErrorContainer
                                              : deleted
                                                  ? theme.colorScheme.onSurfaceVariant
                                                  : isMine
                                                      ? theme.colorScheme.onPrimary
                                                      : theme.textTheme.bodyMedium
                                                          ?.color,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  failed
                                      ? "Failed - Tap to retry"
                                      : "${_formatMessageTime(message["createdAt"])}${pending ? " - sending..." : ""}",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: failed
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: failed
                                        ? theme.colorScheme.onErrorContainer
                                        : isMine
                                            ? theme.colorScheme.onPrimary
                                                .withValues(alpha: 0.7)
                                            : theme
                                                .textTheme.bodySmall?.color,
                                  ),
                                ),
                              ],
                            ),
                          );

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
                                  child: failed
                                      ? InkWell(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          onTap: () => _retryMessage(message),
                                          child: bubble,
                                        )
                                      : GestureDetector(
                                          onLongPress: (pending || deleted)
                                              ? null
                                              : () => _showMessageActions(
                                                  message,
                                                  isMine: isMine),
                                          child: bubble,
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
