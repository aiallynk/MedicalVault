import 'package:flutter/material.dart';
import 'package:hello/api_service.dart';
import 'package:hello/widgets/ai_thinking_indicator.dart';

class CareSearchAiPage extends StatefulWidget {
  const CareSearchAiPage({
    super.key,
    this.reportId,
    this.reportType,
  });

  final String? reportId;
  final String? reportType;

  @override
  State<CareSearchAiPage> createState() => _CareSearchAiPageState();
}

class _CareSearchAiPageState extends State<CareSearchAiPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<_CareSearchMessage> _messages = [];
  String? _conversationId;
  bool _sending = false;
  bool _loadingHistory = true;

  static const _greeting = _CareSearchMessage(
    role: _CareSearchRole.assistant,
    text:
        'CareSearch AI can summarize lost/found reports, compare possible matches, and suggest verification steps.',
  );

  static const List<String> _quickActions = [
    'Find possible matches',
    'Summarize this lost report',
    'Compare with found reports',
    'What information is missing?',
    'Draft verification questions',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final response = await ApiService.getKhojChatHistory();
    if (!mounted) return;
    final rawMessages = (response?['messages'] as List?) ?? const [];
    final loaded = rawMessages
        .map((m) => _CareSearchMessage.fromJson(m as Map))
        .toList();
    setState(() {
      _messages = loaded.isNotEmpty ? loaded : [_greeting];
      _conversationId = response?['conversationId']?.toString();
      _loadingHistory = false;
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? quickAction]) async {
    final text = (quickAction ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _messages.add(
        _CareSearchMessage(role: _CareSearchRole.user, text: text),
      );
      _controller.clear();
    });
    _scrollToBottom();

    final response = await ApiService.askKhojAI(
      message: text,
      reportId: widget.reportId,
      reportType: widget.reportType,
    );
    if (!mounted) return;

    final success = response?['success'] == true;
    final reply =
        (response?['reply'] ?? response?['message'] ?? '').toString().trim();
    setState(() {
      _sending = false;
      _conversationId = response?['conversationId']?.toString() ?? _conversationId;
      _messages.add(
        _CareSearchMessage(
          role: _CareSearchRole.assistant,
          text: reply.isNotEmpty
              ? reply
              : success
                  ? 'CareSearch AI completed the analysis.'
                  : 'CareSearch AI could not complete the request.',
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _startNewChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start new chat?'),
        content: const Text(
          'This will clear the current CareSearch AI conversation. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Start new chat'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ApiService.clearKhojChatHistory();
    if (!mounted) return;
    setState(() {
      _messages = [_greeting];
      _conversationId = null;
    });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('CareSearch AI'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Start new chat',
            onPressed: _startNewChat,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickActions.map((action) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(action),
                        onPressed: _sending ? null : () => _send(action),
                      ),
                    );
                  }).toList(growable: false),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_sending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_sending && index == _messages.length) {
                          return const AiThinkingIndicator(
                            avatarIcon: Icons.person_search_rounded,
                          );
                        }
                        return _MessageBubble(message: _messages[index]);
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.4)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask CareSearch AI about lost/found reports',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : () => _send(),
                    icon: const Icon(Icons.send_rounded),
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CareSearchRole { user, assistant }

class _CareSearchMessage {
  const _CareSearchMessage({
    required this.role,
    required this.text,
  });

  factory _CareSearchMessage.fromJson(Map json) {
    final role = json['role']?.toString() == 'user'
        ? _CareSearchRole.user
        : _CareSearchRole.assistant;
    return _CareSearchMessage(
      role: role,
      text: (json['content'] ?? '').toString(),
    );
  }

  final _CareSearchRole role;
  final String text;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _CareSearchMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _CareSearchRole.user;
    final theme = Theme.of(context);
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 18),
        ),
      ),
      child: SelectableText(
        message.text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isUser ? theme.colorScheme.onPrimary : null,
          height: 1.35,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.person_search_rounded,
                size: 16,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
