import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/ai_service.dart';
import '../widgets/ai_structured_widgets.dart';
import '../widgets/language_selector.dart';
import 'package:hello/localization/app_localizations.dart';

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
  String _selectedLanguage = 'english';
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
          _messages.addAll(savedMessages);
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
    // This would typically use SharedPreferences
    // For now, return empty list
    return [];
  }

  Future<void> _saveMessages() async {
    // This would typically save to SharedPreferences
    // For now, just a placeholder
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
    _saveMessages();

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
    Map<String, dynamic>? documentMetadata,
    List<DocumentInfo>? documents,
  }) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: isUser,
        timestamp: DateTime.now(),
        responseType: responseType,
        structuredData: structuredData,
        documentMetadata: documentMetadata,
        documents: documents,
      ));
    });
    _scrollToBottom();

    // Save messages to storage
    _saveMessages();
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
      );

      setState(() {
        _isTyping = false;
      });
      _typingController.stop();

      if (response.success) {
        // Convert document data to DocumentInfo objects if present
        List<DocumentInfo>? documentInfos;
        if (response.data != null) {
          documentInfos =
              response.data!.map((doc) => DocumentInfo.fromJson(doc)).toList();
        }

        _addMessage(
          response.reply,
          false,
          responseType: response.responseType,
          structuredData: response.structuredData,
          documentMetadata: response.documentMetadata,
          documents: documentInfos,
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
      );

      setState(() {
        _isTyping = false;
      });
      _typingController.stop();

      if (response.success) {
        _addMessage(
          response.reply,
          false,
          responseType: response.responseType,
          structuredData: response.structuredData,
          documentMetadata: response.documentMetadata,
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

  void _onLanguageChanged(String language) {
    setState(() {
      _selectedLanguage = language;
    });
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
          LanguageSelector(
            selectedLanguage: _selectedLanguage,
            onLanguageChanged: _onLanguageChanged,
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
    final l10n = context.l10n;
    switch (_selectedLanguage) {
      case 'hindi':
        return l10n.t('chat.inputHint.hindi');
      case 'marathi':
        return l10n.t('chat.inputHint.marathi');
      case 'hinglish':
        return l10n.t('chat.inputHint.hinglish');
      default:
        return l10n.t('chat.inputHint.english');
    }
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
                  SelectableText(
                    _cleanMessageText(message.text),
                    style: TextStyle(
                      color: message.isUser
                          ? Colors.white
                          : theme.textTheme.bodyLarge?.color,
                      fontSize: 16,
                    ),
                    onSelectionChanged: (selection, cause) {
                      // Handle selection changes
                      if (selection.isValid && !selection.isCollapsed) {
                        // Optional: Show selection feedback
                      }
                    },
                  ),
                  // Add structured data if present
                  if (!message.isUser &&
                      message.responseType == 'table' &&
                      message.structuredData != null)
                    AITableWidget(
                      data: message.structuredData!,
                    ),
                  if (!message.isUser &&
                      message.responseType == 'chart' &&
                      message.structuredData != null)
                    AIChartWidget(
                      data: message.structuredData!,
                      chartType: 'bar',
                    ),
                  // Add document list if present
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
                        ...message.documents!.map((doc) => DocumentPreviewCard(
                              id: doc.id,
                              name: doc.name,
                              type: doc.type,
                              date: doc.date,
                              previewUrl: doc.previewUrl,
                              onTap: () => _analyzeDocument(doc.id, doc.name),
                            )),
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

  String _cleanMessageText(String text) {
    // Remove markdown formatting for clean output
    String cleaned = text;

    // Remove bold formatting **text**
    cleaned = cleaned.replaceAll(RegExp(r'\*\*'), '');

    // Remove italic formatting *text*
    cleaned = cleaned.replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '');

    // Remove headers ### Header
    cleaned = cleaned.replaceAll(RegExp(r'### '), '');

    // Remove headers ## Header
    cleaned = cleaned.replaceAll(RegExp(r'## '), '');

    // Remove headers # Header
    cleaned = cleaned.replaceAll(RegExp(r'# '), '');

    // Remove inline code `code`
    cleaned = cleaned.replaceAll(RegExp(r'`'), '');

    // Remove code blocks ```code```
    cleaned = cleaned.replaceAll(RegExp(r'```'), '');

    // Clean up extra whitespace and lines
    cleaned = cleaned
        .replaceAll(
            RegExp(r'\n\s*\n\s*\n'), '\n\n') // Remove multiple empty lines
        .replaceAll(RegExp(r'^\s+|\s+$'), '') // Trim each line
        .trim();

    return cleaned;
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
              onPressed: () {
                Navigator.of(context).pop();
                _clearChat();
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
  final Map<String, dynamic>? documentMetadata;
  final List<DocumentInfo>? documents;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.responseType,
    this.structuredData,
    this.documentMetadata,
    this.documents,
  });
}
