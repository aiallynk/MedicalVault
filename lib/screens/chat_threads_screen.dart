import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../utils/timezone_utils.dart';
import 'direct_chat_screen.dart';

class ChatThreadsScreen extends StatefulWidget {
  const ChatThreadsScreen({super.key});

  @override
  State<ChatThreadsScreen> createState() => _ChatThreadsScreenState();
}

class _ChatThreadsScreenState extends State<ChatThreadsScreen> {
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  List<Map<String, dynamic>> _threads = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadThreads();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _loadThreads(silent: true),
    );
  }

  /// Cheap content signature used to decide whether a poll actually changed
  /// anything worth rebuilding for — avoids calling setState() (and thus
  /// rebuilding/repainting every thread row) every 4 seconds when the
  /// server returned the same data as before.
  String _threadsSignature(List<Map<String, dynamic>> threads) {
    final buffer = StringBuffer();
    for (final thread in threads) {
      buffer
        ..write(thread['counterpartId'])
        ..write('|')
        ..write(thread['unreadCount'])
        ..write('|')
        ..write(thread['lastMessage'])
        ..write('|')
        ..write(thread['lastAt'])
        ..write(';');
    }
    return buffer.toString();
  }

  Future<void> _loadThreads({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final threads = await ApiService.fetchChatThreads();
      if (!mounted) return;
      final changed = _threadsSignature(threads) != _threadsSignature(_threads);
      if (changed || _loading || _error != null) {
        setState(() {
          _threads = threads;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _confirmDeleteThread(
    Map<String, dynamic> thread, {
    required String mode,
  }) async {
    final counterpartId = (thread["counterpartId"] ?? "").toString().trim();
    if (counterpartId.isEmpty) return;

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

    final success = await ApiService.deleteChatThread(counterpartId, mode: mode);
    if (!mounted) return;
    if (success) {
      setState(() {
        _threads.removeWhere(
          (item) => (item["counterpartId"] ?? "").toString() == counterpartId,
        );
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete chat. Please try again.')),
      );
    }
  }

  void _showThreadOptions(Map<String, dynamic> thread) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete for me'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDeleteThread(thread, mode: 'me');
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: Text(
                'Delete for everyone',
                style: TextStyle(color: Theme.of(sheetContext).colorScheme.error),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDeleteThread(thread, mode: 'everyone');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openThread(Map<String, dynamic> thread) {
    final counterpartId = (thread["counterpartId"] ?? "").toString().trim();
    if (counterpartId.isEmpty) return;

    final counterpartNameRaw =
        (thread["counterpartName"] ?? "Doctor").toString().trim();
    final counterpartName = counterpartNameRaw.isEmpty
        ? "Doctor"
        : counterpartNameRaw.toLowerCase().startsWith("dr.")
            ? counterpartNameRaw
            : "Dr. $counterpartNameRaw";
    final counterpartAvatar = ApiService.resolveMediaUrl(
          (thread["counterpartAvatar"] ?? "").toString(),
        ) ??
        "";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectChatScreen(
          counterpartId: counterpartId,
          counterpartName: counterpartName,
          // Flutter app is patient-side. Counterpart in direct chat is doctor.
          counterpartRole: "doctor",
          counterpartAvatarUrl: counterpartAvatar,
        ),
      ),
    ).then((_) => _loadThreads(silent: true));
  }

  String _formatMessageTime(dynamic raw) {
    final timeLabel = formatTimeForContext(
      context,
      raw,
      pattern: 'h:mm a',
      fallback: '',
    );
    if (timeLabel.isEmpty) return '';

    final messageDay = formatDateForContext(
      context,
      raw,
      pattern: 'yyyy-MM-dd',
      fallback: '',
    );
    final today = formatDateForContext(
      context,
      nowForContextTimeZone(context),
      pattern: 'yyyy-MM-dd',
      fallback: '',
    );
    if (messageDay.isNotEmpty && messageDay == today) {
      return timeLabel;
    }

    return formatDateForContext(
      context,
      raw,
      pattern: 'dd/MM',
      fallback: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadThreads(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _threads.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "No conversations yet.",
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadThreads,
                  child: ListView.separated(
                    itemCount: _threads.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: theme.dividerColor.withValues(alpha: 0.5),
                    ),
                    itemBuilder: (context, index) {
                      final thread = _threads[index];
                      final message =
                          (thread["lastMessage"] ?? "No messages yet")
                              .toString();
                      final unread = int.tryParse(
                              (thread["unreadCount"] ?? "0").toString()) ??
                          0;
                      final avatar = ApiService.resolveMediaUrl(
                            (thread["counterpartAvatar"] ?? "").toString(),
                          ) ??
                          "";
                      final rawName =
                          (thread["counterpartName"] ?? "Doctor").toString();
                      final displayName = rawName.trim().isEmpty
                          ? "Doctor"
                          : rawName.toLowerCase().startsWith("dr.")
                              ? rawName
                              : "Dr. $rawName";

                      return ListTile(
                        onTap: () => _openThread(thread),
                        onLongPress: () => _showThreadOptions(thread),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundImage:
                              avatar.isNotEmpty ? NetworkImage(avatar) : null,
                          child: avatar.isEmpty
                              ? const Icon(Icons.medical_services_rounded)
                              : null,
                        ),
                        title: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatMessageTime(thread["lastAt"]),
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                if (unread > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.error,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      unread > 99 ? "99+" : "$unread",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Chat options',
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.more_vert, size: 20),
                              onSelected: (mode) =>
                                  _confirmDeleteThread(thread, mode: mode),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'me',
                                  child: Text('Delete for me'),
                                ),
                                PopupMenuItem(
                                  value: 'everyone',
                                  child: Text('Delete for everyone'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: _error == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.error,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
    );
  }
}
