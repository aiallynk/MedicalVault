import 'package:flutter/material.dart';
import 'package:hello/api_service.dart';

class KhojAiPage extends StatefulWidget {
  const KhojAiPage({
    super.key,
    this.reportId,
    this.reportType,
  });

  final String? reportId;
  final String? reportType;

  @override
  State<KhojAiPage> createState() => _KhojAiPageState();
}

class _KhojAiPageState extends State<KhojAiPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_KhojMessage> _messages = [
    _KhojMessage(
      role: _KhojRole.assistant,
      text:
          'KHOJ AI can summarize lost/found reports, compare possible matches, and suggest verification steps.',
    ),
  ];
  bool _sending = false;

  static const List<String> _quickActions = [
    'Find possible matches',
    'Summarize this lost report',
    'Compare with found reports',
    'What information is missing?',
    'Draft verification questions',
  ];

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
      _messages.add(_KhojMessage(role: _KhojRole.user, text: text));
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
      _messages.add(
        _KhojMessage(
          role: _KhojRole.assistant,
          text: reply.isNotEmpty
              ? reply
              : success
                  ? 'KHOJ AI completed the analysis.'
                  : 'KHOJ AI could not complete the request.',
        ),
      );
    });
    _scrollToBottom();
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
        title: const Text('KHOJ AI'),
        centerTitle: true,
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
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_sending && index == _messages.length) {
                    return const _TypingBubble();
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
                        hintText: 'Ask KHOJ AI about lost/found reports',
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

enum _KhojRole { user, assistant }

class _KhojMessage {
  const _KhojMessage({
    required this.role,
    required this.text,
  });

  final _KhojRole role;
  final String text;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _KhojMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _KhojRole.user;
    final theme = Theme.of(context);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isUser ? theme.colorScheme.onPrimary : null,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
