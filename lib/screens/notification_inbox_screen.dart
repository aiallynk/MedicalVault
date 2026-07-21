import 'package:flutter/material.dart';

import '../api_service.dart';

/// Notification inbox: lists the account's persisted notification history
/// (Backend-MedicalVault's Notification model) with server-side cursor
/// pagination and infinite scroll, reachable from the bell icon on the
/// dashboard. Tapping a notification marks it read; a swipe or the per-item
/// menu deletes it; the overflow menu offers Clear all.
class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  static const int _pageSize = 20;
  static const double _loadMoreTriggerOffset = 320;

  final ScrollController _scrollController = ScrollController();
  final Set<String> _seenIds = <String>{};

  List<Map<String, dynamic>> _notifications = [];
  String? _nextCursor;
  bool _hasMore = true;

  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;
  bool _clearing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  String _idOf(Map<String, dynamic> notification) =>
      (notification['_id'] ?? notification['id'] ?? '').toString();

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_loadingInitial || _loadingMore || !_hasMore) return;
    final trigger =
        _scrollController.position.maxScrollExtent - _loadMoreTriggerOffset;
    if (_scrollController.position.pixels >= trigger) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _error = null;
    });
    final inbox = await ApiService.fetchNotificationInbox(limit: _pageSize);
    if (!mounted) return;
    if (inbox['success'] != true) {
      setState(() {
        _loadingInitial = false;
        _error = 'Could not load notifications.';
      });
      return;
    }
    final items =
        List<Map<String, dynamic>>.from(inbox['notifications'] as List);
    _seenIds
      ..clear()
      ..addAll(items.map(_idOf).where((id) => id.isNotEmpty));
    setState(() {
      _notifications = items;
      _nextCursor = inbox['nextCursor'] as String?;
      _hasMore = inbox['hasMore'] == true;
      _loadingInitial = false;
      _loadMoreFailed = false;
    });
  }

  /// Loads the next page and appends only genuinely-new notifications
  /// (deduplicated by id), so a retried request or a race with a pull-to-
  /// refresh never inserts the same notification twice.
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    final inbox = await ApiService.fetchNotificationInbox(
      cursor: _nextCursor,
      limit: _pageSize,
    );
    if (!mounted) return;
    if (inbox['success'] != true) {
      setState(() {
        _loadingMore = false;
        _loadMoreFailed = true;
      });
      return;
    }
    final items =
        List<Map<String, dynamic>>.from(inbox['notifications'] as List);
    final fresh = items.where((item) {
      final id = _idOf(item);
      if (id.isEmpty || _seenIds.contains(id)) return false;
      _seenIds.add(id);
      return true;
    }).toList(growable: false);
    setState(() {
      _notifications = [..._notifications, ...fresh];
      _nextCursor = inbox['nextCursor'] as String?;
      _hasMore = inbox['hasMore'] == true;
      _loadingMore = false;
    });
  }

  Future<void> _refresh() async {
    await _loadInitial();
  }

  Future<void> _markAllRead() async {
    final success = await ApiService.markAllNotificationsRead();
    if (!mounted) return;
    if (success) {
      setState(() {
        _notifications = _notifications
            .map((item) => {...item, 'read': true})
            .toList(growable: false);
      });
    }
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    final id = _idOf(notification);
    if (id.isEmpty) return;
    if (notification['read'] != true) {
      final success = await ApiService.markNotificationRead(id);
      if (success && mounted) {
        setState(() {
          final index =
              _notifications.indexWhere((item) => _idOf(item) == id);
          if (index != -1) {
            _notifications[index] = {..._notifications[index], 'read': true};
          }
        });
      }
    }
  }

  Future<void> _deleteNotification(Map<String, dynamic> notification) async {
    final id = _idOf(notification);
    if (id.isEmpty) return;
    final removed = notification;
    setState(() {
      _notifications.removeWhere((item) => _idOf(item) == id);
      _seenIds.remove(id);
    });
    final success = await ApiService.deleteNotification(id);
    if (!success && mounted) {
      setState(() {
        _notifications.insert(0, removed);
        _seenIds.add(id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete notification.')),
      );
    }
  }

  Future<void> _confirmClearAll() async {
    if (_notifications.isEmpty || _clearing) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _ClearAllConfirmationSheet(),
    );
    if (confirmed != true || !mounted) return;
    await _clearAll();
  }

  Future<void> _clearAll() async {
    setState(() => _clearing = true);
    // Snapshot for rollback: a failed Clear All must restore exactly what
    // was visible before, not just say "something went wrong".
    final previousNotifications = _notifications;
    final previousCursor = _nextCursor;
    final previousHasMore = _hasMore;
    final previousSeenIds = Set<String>.from(_seenIds);

    final deletedCount = await ApiService.clearAllNotifications();
    if (!mounted) return;

    if (deletedCount == null) {
      setState(() {
        _clearing = false;
        _notifications = previousNotifications;
        _nextCursor = previousCursor;
        _hasMore = previousHasMore;
        _seenIds
          ..clear()
          ..addAll(previousSeenIds);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not clear notifications. Try again.'),
          action: SnackBarAction(label: 'Retry', onPressed: _clearAll),
        ),
      );
      return;
    }

    setState(() {
      _clearing = false;
      _notifications = [];
      _seenIds.clear();
      _nextCursor = null;
      _hasMore = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notifications cleared.')),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'appointment':
        return Icons.calendar_month_rounded;
      case 'session':
        return Icons.chat_bubble_rounded;
      case 'document':
        return Icons.description_rounded;
      case 'chat':
        return Icons.forum_rounded;
      case 'caregiver':
      case 'family_care_medication':
      case 'family_care_connection':
        return Icons.family_restroom_rounded;
      case 'emergency':
        return Icons.emergency_rounded;
      case 'qr_scan':
        return Icons.qr_code_rounded;
      case 'reminder':
        return Icons.alarm_rounded;
      case 'lost_person_alert':
        return Icons.person_search_rounded;
      case 'system':
        return Icons.info_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _timeAgo(Map<String, dynamic> notification) {
    final explicit = notification['timeAgo']?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final createdAtRaw = notification['createdAt'];
    final createdAt = createdAtRaw != null
        ? DateTime.tryParse(createdAtRaw.toString())
        : null;
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasUnread = _notifications.any((item) => item['read'] != true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
          // Deliberately unobtrusive: tucked in the overflow menu rather than
          // a standalone always-visible button, and disabled (not hidden, so
          // its position stays predictable) when there is nothing to clear.
          PopupMenuButton<String>(
            enabled: _notifications.isNotEmpty && !_clearing,
            onSelected: (value) {
              if (value == 'clear_all') _confirmClearAll();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear_all',
                enabled: _notifications.isNotEmpty && !_clearing,
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined,
                        size: 18, color: scheme.error),
                    const SizedBox(width: 10),
                    const Text('Clear all'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: _loadingInitial
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                              onPressed: _loadInitial,
                              child: const Text('Retry')),
                        ],
                      ),
                    ),
                  )
                : _notifications.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 120),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.notifications_none_rounded,
                                      size: 48,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No notifications yet.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              color: scheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.separated(
                          controller: _scrollController,
                          itemCount:
                              _notifications.length + (_hasMore || _loadMoreFailed ? 1 : 0),
                          separatorBuilder: (_, index) {
                            if (index >= _notifications.length - 1) {
                              return const SizedBox.shrink();
                            }
                            return Divider(
                              height: 1,
                              color: theme.dividerColor.withValues(alpha: 0.5),
                            );
                          },
                          itemBuilder: (context, index) {
                            if (index >= _notifications.length) {
                              return _buildFooter(scheme);
                            }
                            final notification = _notifications[index];
                            final isRead = notification['read'] == true;
                            final type =
                                (notification['type'] ?? 'general').toString();

                            return Dismissible(
                              key: ValueKey(_idOf(notification).isEmpty
                                  ? index
                                  : _idOf(notification)),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: scheme.error,
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: const Icon(Icons.delete_outline,
                                    color: Colors.white),
                              ),
                              onDismissed: (_) =>
                                  _deleteNotification(notification),
                              child: ListTile(
                                onTap: () => _openNotification(notification),
                                tileColor: isRead
                                    ? null
                                    : scheme.primary.withValues(alpha: 0.06),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      scheme.primary.withValues(alpha: 0.12),
                                  child: Icon(_iconForType(type),
                                      color: scheme.primary),
                                ),
                                title: Text(
                                  (notification['title'] ?? '').toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight:
                                        isRead ? FontWeight.w500 : FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  (notification['body'] ?? '').toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _timeAgo(notification),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    if (!isRead) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: scheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }

  Widget _buildFooter(ColorScheme scheme) {
    if (_loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load more notifications.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _loadMore,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ClearAllConfirmationSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Clear all notifications?',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will permanently remove your notification history.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Clear all'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
