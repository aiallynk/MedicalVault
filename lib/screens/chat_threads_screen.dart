import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
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
      setState(() {
        _threads = threads;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _openThread(Map<String, dynamic> thread) {
    final counterpartId = (thread["counterpartId"] ?? "").toString().trim();
    if (counterpartId.isEmpty) return;

    final counterpartName =
        (thread["counterpartName"] ?? "Conversation").toString().trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectChatScreen(
          counterpartId: counterpartId,
          counterpartName:
              counterpartName.isEmpty ? "Conversation" : counterpartName,
          // Flutter app is patient-side. Counterpart in direct chat is doctor.
          counterpartRole: "doctor",
        ),
      ),
    ).then((_) => _loadThreads(silent: true));
  }

  String _formatMessageTime(dynamic raw) {
    final value = raw?.toString() ?? "";
    if (value.isEmpty) return "";
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return "";
    final local = parsed.toLocal();
    final now = DateTime.now();
    final sameDay = now.year == local.year &&
        now.month == local.month &&
        now.day == local.day;
    if (sameDay) {
      final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      final suffix = local.hour >= 12 ? 'PM' : 'AM';
      return "$hour:$minute $suffix";
    }
    return "${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}";
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
                      final name = (thread["counterpartName"] ?? "Conversation")
                          .toString();
                      final message =
                          (thread["lastMessage"] ?? "No messages yet")
                              .toString();
                      final unread = int.tryParse(
                              (thread["unreadCount"] ?? "0").toString()) ??
                          0;
                      final avatar =
                          (thread["counterpartAvatar"] ?? "").toString().trim();

                      return ListTile(
                        onTap: () => _openThread(thread),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundImage:
                              avatar.isNotEmpty ? NetworkImage(avatar) : null,
                          child: avatar.isEmpty
                              ? const Icon(Icons.person_outline_rounded)
                              : null,
                        ),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
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
