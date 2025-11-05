import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/ai_service.dart';
import '../widgets/ai_structured_widgets.dart';
import '../widgets/language_selector.dart';

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
      _addMessage(
        "I see you want to analyze: ${widget.initialDocumentName}. Let me help you with that!",
        false,
      );
      // Auto-analyze the document
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _analyzeDocument(
            widget.initialDocumentId!, widget.initialDocumentName!);
      });
    }
  }

  Future<void> _loadSavedMessages() async {
    try {
      final savedMessages = await _getSavedMessages();

      if (savedMessages.isNotEmpty) {
        setState(() {
          _messages.addAll(savedMessages);
        });
        _scrollToBottom();
      } else {
        // Add welcome message if no saved messages
        _addMessage(
          "Hello! I'm your Medical Vault AI Assistant 🤖 How can I help you today?",
          false,
        );
        _addMessage(
          "I can analyze your documents, provide insights, and answer in multiple languages. "
          "Please log in first to access your medical documents and get personalized assistance!",
          false,
        );
      }
    } catch (e) {
      print('Error loading saved messages: $e');
      // Fallback to welcome message
      _addMessage(
        "Hello! I'm your Medical Vault AI Assistant 🤖 How can I help you today?",
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
      "Hello! I'm your Medical Vault AI Assistant 🤖 How can I help you today?",
      false,
    );
    _addMessage(
      "I can analyze your documents, provide insights, and answer in multiple languages. "
      "Please log in first to access your medical documents and get personalized assistance!",
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
            '🔐 Please log in to use the AI Assistant!\n\n'
            'You can log in from the Settings page or by tapping the profile icon. '
            'Once logged in, I can help you analyze your medical documents and answer questions about your health records.\n\n'
            '💡 Tip: Use the navigation bar to go to Settings and log in with your credentials.',
            false,
          );
        } else {
          _addMessage(
            response.message ??
                'Sorry, I encountered an error. Please try again.',
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
        'Sorry, I encountered an error. Please try again.',
        false,
      );
    }
  }

  Future<void> _analyzeDocument(String documentId, String documentName) async {
    final userMessage = "Analyze this document: $documentName";

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
        prompt: "Please analyze this document and provide insights",
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
          response.message ?? 'Sorry, I could not analyze the document.',
          false,
        );
      }
    } catch (e) {
      setState(() {
        _isTyping = false;
      });
      _typingController.stop();
      _addMessage(
        'Sorry, I encountered an error while analyzing the document.',
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
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Assistant 🤖',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
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
            tooltip: 'Clear Chat',
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
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDarkMode ? Colors.white12 : Colors.black12,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF2E2E2E)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: _getHintText(),
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.white60 : Colors.grey[600],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent,
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
    switch (_selectedLanguage) {
      case 'hindi':
        return 'अपने स्वास्थ्य रिकॉर्ड के बारे में पूछें...';
      case 'marathi':
        return 'तुमच्या आरोग्य रेकॉर्ड्स बद्दल विचारा...';
      case 'hinglish':
        return 'Ask about your health records...';
      default:
        return 'Ask me about your health records...';
    }
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

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
                color: Colors.deepPurpleAccent,
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
                color: message.isUser
                    ? Colors.deepPurpleAccent
                    : (isDarkMode ? const Color(0xFF2E2E2E) : Colors.grey[100]),
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
                          : (isDarkMode ? Colors.white : Colors.black87),
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
                          'Documents:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
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
                color: isDarkMode ? const Color(0xFF2E2E2E) : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.person,
                color: isDarkMode ? Colors.white70 : Colors.grey[600],
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent,
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2E2E2E)
                  : Colors.grey[100],
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
    final delay = index * 0.2;
    final animationValue = (_typingAnimation.value + delay) % 1.0;
    final opacity =
        (animationValue < 0.5) ? animationValue * 2 : (1 - animationValue) * 2;

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white70
            : Colors.grey[600],
        shape: BoxShape.circle,
      ),
      child: Opacity(
        opacity: opacity,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : Colors.grey[600],
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
          title: const Text('Clear Chat'),
          content: const Text(
              'Are you sure you want to clear all chat messages? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearChat();
              },
              child: const Text('Clear'),
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
