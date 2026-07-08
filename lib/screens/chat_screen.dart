import 'package:flutter/material.dart';
import 'dart:async';
import '../services/ai_service.dart';
import '../widgets/ai_structured_widgets.dart';
import 'package:hello/localization/app_localizations.dart';
import '../features/lost_found/lost_person_detail_page.dart';

class ChatScreen extends StatefulWidget {
  final String? initialDocumentId;
  final String? initialDocumentName;

  const ChatScreen({
    super.key,
    this.initialDocumentId,
    this.initialDocumentName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  String? _conversationId;
  late AnimationController _typingController;
  late Animation<double> _typingAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize typing animation
    _typingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _typingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _typingController,
      curve: Curves.easeInOut,
    ));

    // Load saved chat messages
    _loadSavedMessages();

    if (widget.initialDocumentId != null &&
        widget.initialDocumentName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final l10n = context.l10n;
        _addMessage(
          l10n.format(
              'chat.autoAnalyze', {'name': widget.initialDocumentName!}),
          false,
        );
        _analyzeDocument(
            widget.initialDocumentId!, widget.initialDocumentName!);
      });
    }
  }

  Future<void> _loadSavedMessages() async {
    try {
      if (!mounted) return;
      final l10n = context.l10n;
      final savedMessages = await _getSavedMessages();

      if (savedMessages.isNotEmpty) {
        setState(() {
          _messages
            ..clear()
            ..addAll(savedMessages);
        });
        _scrollToBottom();
      } else {
        // Add welcome message if no saved messages
        _addMessage(
          l10n.t('chat.welcome.greeting'),
          false,
        );
        _addMessage(
          l10n.t('chat.welcome.helper'),
          false,
        );
      }
    } catch (e) {
      print('Error loading saved messages: $e');
      // Fallback to welcome message
      if (!mounted) return;
      final l10n = context.l10n;
      _addMessage(
        l10n.t('chat.welcome.greeting'),
        false,
      );
    }
  }

  Future<List<ChatMessage>> _getSavedMessages() async {
    final history = await AIService.getChatHistory();
    if (history == null) return const <ChatMessage>[];

    _conversationId = history['conversationId']?.toString();
    final rawMessages = history['messages'];
    if (rawMessages is! List) return const <ChatMessage>[];

    final parsed = <ChatMessage>[];
    for (final entry in rawMessages) {
      if (entry is! Map) continue;
      final mapped = entry.map((key, value) => MapEntry(key.toString(), value));
      final role = (mapped['role'] ?? '').toString().trim().toLowerCase();
      final content = (mapped['content'] ?? '').toString();
      if (content.trim().isEmpty) continue;

      final metadataRaw = mapped['metadata'];
      final metadata = metadataRaw is Map
          ? metadataRaw.map((k, v) => MapEntry(k.toString(), v))
          : <String, dynamic>{};

      List<Map<String, dynamic>>? asMapList(dynamic value) {
        if (value is! List) return null;
        final out = value
            .whereType<Map>()
            .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
            .toList(growable: false);
        return out.isEmpty ? null : out;
      }

      Map<String, dynamic>? asMap(dynamic value) {
        if (value is Map<String, dynamic>) return value;
        if (value is Map) {
          return value.map((k, v) => MapEntry(k.toString(), v));
        }
        return null;
      }

      List<DocumentInfo>? docs;
      final dataList = asMapList(metadata['data']);
      if (dataList != null) {
        final docLike = dataList.where((item) {
          final name = (item['name'] ?? item['title'] ?? '').toString().trim();
          return name.isNotEmpty;
        }).toList(growable: false);
        if (docLike.isNotEmpty) {
          docs = docLike
              .map((item) => DocumentInfo.fromJson(item))
              .toList(growable: false);
        }
      }

      DateTime timestamp;
      try {
        timestamp = DateTime.parse((mapped['timestamp'] ?? '').toString());
      } catch (_) {
        timestamp = DateTime.now();
      }

      parsed.add(
        ChatMessage(
          text: content,
          isUser: role == 'user',
          timestamp: timestamp,
          responseType: metadata['responseType']?.toString(),
          structuredData: asMap(metadata['structuredData']),
          sections: asMapList(metadata['sections']),
          safety: asMap(metadata['safety']),
          context: asMap(metadata['context']),
          documentMetadata: asMap(metadata['documentMetadata']),
          documents: docs,
        ),
      );
    }
    return parsed;
  }

  Future<void> _clearChat() async {
    await AIService.clearChatHistory();
    setState(() {
      _messages.clear();
      _conversationId = null;
    });

    // Add welcome message
    _addMessage(
      context.l10n.t('chat.welcome.greeting'),
      false,
    );
    _addMessage(
      context.l10n.t('chat.welcome.helper'),
      false,
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingController.dispose();
    super.dispose();
  }

  void _addMessage(
    String text,
    bool isUser, {
    String? responseType,
    Map<String, dynamic>? structuredData,
    List<Map<String, dynamic>>? sections,
    Map<String, dynamic>? safety,
    Map<String, dynamic>? context,
    Map<String, dynamic>? documentMetadata,
    List<DocumentInfo>? documents,
    List<Map<String, dynamic>>? lostPersonResults,
  }) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: isUser,
        timestamp: DateTime.now(),
        responseType: responseType,
        structuredData: structuredData,
        sections: sections,
        safety: safety,
        context: context,
        documentMetadata: documentMetadata,
        documents: documents,
        lostPersonResults: lostPersonResults,
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    // Add user message
    _addMessage(userMessage, true);

    // Show typing indicator
    setState(() {
      _isTyping = true;
    });
    _typingController.repeat();

    try {
      // Send message to AI service
      final response = await AIService.sendMessage(
        prompt: userMessage,
        context: {
          'preferredLanguage': Localizations.localeOf(context).languageCode,
          'userInputLanguage': AIService.detectLanguage(userMessage),
          'voiceMode': false,
          'activeProfile': null,
          'selectedPatientProfile': null,
          'authorizedSessionScope': 'self_profile',
          if (_conversationId != null) 'conversationId': _conversationId,
          'appLocale': Localizations.localeOf(context).languageCode,
        },
      );

      setState(() {
        _isTyping = false;
      });
      _typingController.stop();

      if (response.success) {
        _conversationId =
            response.context?['conversationId']?.toString() ?? _conversationId;
        final lostPersonResults = response.responseType == 'lost_person_results'
            ? (response.items ?? response.data)
            : null;
        // Convert document data to DocumentInfo objects if present.
        List<DocumentInfo>? documentInfos;
        if (response.data != null && lostPersonResults == null) {
          documentInfos =
              response.data!.map((doc) => DocumentInfo.fromJson(doc)).toList();
        }

        _addMessage(
          response.reply,
          false,
          responseType: response.responseType,
          structuredData: response.structuredData,
          sections: response.sections,
          safety: response.safety,
          context: response.context,
          documentMetadata: response.documentMetadata,
          documents: documentInfos,
          lostPersonResults: lostPersonResults,
        );
      } else {
        // Handle authentication error specifically
        if (response.message?.contains('No authentication token') == true) {
          _addMessage(
            context.l10n.t('chat.loginRequired'),
            false,
          );
        } else {
          _addMessage(
            response.message ?? context.l10n.t('chat.error.generic'),
            false,
          );
        }
      }
    } catch (e) {
      setState(() {
        _isTyping = false;
      });
      _typingController.stop();
      _addMessage(
        context.l10n.t('chat.error.generic'),
        false,
      );
    }
  }

  Future<void> _analyzeDocument(String documentId, String documentName) async {
    final userMessage =
        context.l10n.format('chat.userAnalyzePrompt', {'name': documentName});

    // Add user message
    _addMessage(userMessage, true);

    // Show typing indicator
    setState(() {
      _isTyping = true;
    });
    _typingController.repeat();

    try {
      // Send document analysis request to AI service
      final response = await AIService.sendMessage(
        prompt: context.l10n.t('chat.aiAnalyzePrompt'),
        documentId: documentId,
        context: {
          'preferredLanguage': Localizations.localeOf(context).languageCode,
          'userInputLanguage': AIService.detectLanguage(
            context.l10n.t('chat.aiAnalyzePrompt'),
          ),
          'voiceMode': false,
          'activeProfile': null,
          'selectedPatientProfile': null,
          'authorizedSessionScope': 'self_profile',
          if (_conversationId != null) 'conversationId': _conversationId,
          'appLocale': Localizations.localeOf(context).languageCode,
        },
      );

      setState(() {
        _isTyping = false;
      });
      _typingController.stop();

      if (response.success) {
        _conversationId =
            response.context?['conversationId']?.toString() ?? _conversationId;
        _addMessage(
          response.reply,
          false,
          responseType: response.responseType,
          structuredData: response.structuredData,
          sections: response.sections,
          safety: response.safety,
          context: response.context,
          documentMetadata: response.documentMetadata,
          lostPersonResults: response.responseType == 'lost_person_results'
              ? (response.items ?? response.data)
              : null,
        );
      } else {
        _addMessage(
          response.message ?? context.l10n.t('chat.error.analysis'),
          false,
        );
      }
    } catch (e) {
      setState(() {
        _isTyping = false;
      });
      _typingController.stop();
      _addMessage(
        context.l10n.t('chat.error.analysis'),
        false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceAlt = theme.colorScheme.surfaceContainerHighest;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.t('chat.title'),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: theme.cardColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Clear chat button
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              _showClearChatDialog();
            },
            tooltip: context.l10n.t('chat.tooltip.clear'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: surfaceAlt,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: _getHintText(),
                        hintStyle: theme.textTheme.bodyMedium,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      style: theme.textTheme.bodyLarge,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getHintText() {
    return context.l10n.t('chat.inputHint.english');
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final theme = Theme.of(context);
    final surfaceAlt = theme.colorScheme.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser ? theme.colorScheme.primary : surfaceAlt,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: message.isUser
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: message.isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isUser)
                    SelectableText(
                      message.text.trim(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    )
                  else
                    AIMessageStructuredWidget(
                      text: message.text,
                      sections: message.sections,
                      structuredData: message.structuredData,
                      responseType: message.responseType,
                      safety: message.safety,
                    ),
                  // Add document list if present.
                  if (!message.isUser &&
                      message.documents != null &&
                      message.documents!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.t('chat.documentsLabel'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...message.documents!.map(
                          (doc) => DocumentPreviewCard(
                            id: doc.id,
                            name: doc.name,
                            type: doc.type,
                            date: doc.date,
                            previewUrl: doc.previewUrl,
                            onTap: () => _analyzeDocument(doc.id, doc.name),
                          ),
                        ),
                      ],
                    ),
                  if (!message.isUser &&
                      message.lostPersonResults != null &&
                      message.lostPersonResults!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        ...message.lostPersonResults!.map(
                          (report) => _LostPersonChatCard(
                            report: report,
                            onTap: () {
                              final id = report['id']?.toString() ?? '';
                              if (id.isEmpty) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      LostPersonDetailPage(reportId: id),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: surfaceAlt,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.person,
                color: theme.textTheme.bodyMedium?.color,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final theme = Theme.of(context);
    final surfaceAlt = theme.colorScheme.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceAlt,
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomLeft: const Radius.circular(4),
              ),
            ),
            child: AnimatedBuilder(
              animation: _typingAnimation,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTypingDot(0),
                    const SizedBox(width: 4),
                    _buildTypingDot(1),
                    const SizedBox(width: 4),
                    _buildTypingDot(2),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    final theme = Theme.of(context);
    final dotColor = theme.textTheme.bodyMedium?.color ?? Colors.grey[600];
    final delay = index * 0.2;
    final animationValue = (_typingAnimation.value + delay) % 1.0;
    final opacity =
        (animationValue < 0.5) ? animationValue * 2 : (1 - animationValue) * 2;

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
      child: Opacity(
        opacity: opacity,
        child: Container(
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.l10n.t('chat.clearDialog.title')),
          content: Text(context.l10n.t('chat.clearDialog.message')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(context.l10n.t('common.cancel')),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _clearChat();
              },
              child: Text(context.l10n.t('chat.clearDialog.confirm')),
            ),
          ],
        );
      },
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? responseType;
  final Map<String, dynamic>? structuredData;
  final List<Map<String, dynamic>>? sections;
  final Map<String, dynamic>? safety;
  final Map<String, dynamic>? context;
  final Map<String, dynamic>? documentMetadata;
  final List<DocumentInfo>? documents;
  final List<Map<String, dynamic>>? lostPersonResults;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.responseType,
    this.structuredData,
    this.sections,
    this.safety,
    this.context,
    this.documentMetadata,
    this.documents,
    this.lostPersonResults,
  });
}

class _LostPersonChatCard extends StatelessWidget {
  const _LostPersonChatCard({
    required this.report,
    required this.onTap,
  });

  final Map<String, dynamic> report;
  final VoidCallback onTap;

  String _value(String key, [String fallback = '']) {
    final value = report[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      child: ListTile(
        leading: const Icon(Icons.person_search_rounded),
        title: Text(
          _value('personName', 'Unnamed person'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            _value('lastSeenLocation', 'Location unavailable'),
            _value('status', 'open'),
          ].join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: theme.colorScheme.primary,
        ),
        onTap: onTap,
      ),
    );
  }
}
