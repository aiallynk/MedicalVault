import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/family_care/providers/active_patient_profile_provider.dart';
import '../features/lost_found/lost_person_detail_page.dart';
import '../services/ai_service.dart';
import '../utils/timezone_utils.dart';
import '../widgets/ai_structured_widgets.dart';
import '../widgets/ai_thinking_indicator.dart';
import 'document_preview_screen.dart';

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

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isTyping = false;
  bool _isRestoring = true;
  bool _hasResolvedProfile = false;
  bool _handledInitialDocument = false;
  int _restoreRequest = 0;
  String? _conversationId;
  String? _patientProfileId;
  String? _profileDisplayName;
  String? _observedProfileId;
  String _processingLabel = 'Preparing your answer…';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selectedProfile =
        context.watch<ActivePatientProfileProvider>().activeProfile;
    final requestedProfileId = selectedProfile?.id;
    if (!_hasResolvedProfile || requestedProfileId != _observedProfileId) {
      _hasResolvedProfile = true;
      _observedProfileId = requestedProfileId;
      _loadActiveConversation(requestedProfileId);
    }
  }

  Future<void> _loadActiveConversation(String? requestedProfileId) async {
    final request = ++_restoreRequest;
    if (mounted) {
      setState(() {
        _isRestoring = true;
        _messages.clear();
        _conversationId = null;
      });
    }

    final history = await AIService.getActiveConversation(
      patientProfileId: requestedProfileId,
    );
    if (!mounted || request != _restoreRequest) return;

    final profile = _map(history?['patientProfile']);
    final rawMessages = history?['messages'];
    final restored = rawMessages is List
        ? rawMessages
            .whereType<Map>()
            .map((entry) => ChatMessage.fromServer(
                  entry.map((key, value) => MapEntry(key.toString(), value)),
                ))
            .where((entry) => entry.text.isNotEmpty)
            .toList(growable: false)
        : const <ChatMessage>[];

    setState(() {
      _conversationId = history?['conversationId']?.toString();
      _patientProfileId =
          profile['id']?.toString() ?? requestedProfileId ?? _patientProfileId;
      _profileDisplayName = profile['displayName']?.toString();
      _messages
        ..clear()
        ..addAll(restored);
      _isRestoring = false;
    });
    _scrollToBottom();

    if (!_handledInitialDocument &&
        widget.initialDocumentId != null &&
        widget.initialDocumentName != null) {
      _handledInitialDocument = true;
      await _analyzeDocument(widget.initialDocumentId!, widget.initialDocumentName!);
    }
  }

  Map<String, dynamic> _map(dynamic value) => value is Map
      ? value.map((key, item) => MapEntry(key.toString(), item))
      : <String, dynamic>{};

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _profileName() {
    final selected =
        context.read<ActivePatientProfileProvider>().activeProfile?.displayName;
    return selected ?? _profileDisplayName ?? 'your';
  }

  String _profileSubtitle() {
    final name = _profileName();
    return name == 'your' ? 'Viewing your health records' : 'Viewing $name’s health records';
  }

  String _statusFor(String prompt, {bool isDocument = false}) {
    final value = prompt.toLowerCase();
    if (isDocument || RegExp(r'\b(analy[sz]e|interpret)\b').hasMatch(value)) {
      return 'Analyzing the selected report…';
    }
    if (RegExp(r'\b(compare|comparison|versus|vs\.)\b').hasMatch(value)) {
      return 'Comparing selected reports…';
    }
    if (RegExp(r'\b(medicine|medication|dose|refill|tablet|prescription)\b').hasMatch(value)) {
      return 'Reviewing medicine records…';
    }
    if (RegExp(r'\b(appointment|consultation|follow[- ]?up|doctor visit)\b').hasMatch(value)) {
      return 'Reviewing appointment history…';
    }
    if (RegExp(r'\b(find|search|show|list|available|latest)\b.*\b(report|document|record|file)\b')
        .hasMatch(value)) {
      return 'Searching your health records…';
    }
    if (RegExp(r'\b(summary|summarize|timeline)\b').hasMatch(value)) {
      return 'Preparing a health summary…';
    }
    return 'Preparing your answer…';
  }

  Map<String, dynamic> _requestContext(String prompt) => {
        'preferredLanguage': Localizations.localeOf(context).languageCode,
        'userInputLanguage': AIService.detectLanguage(prompt),
        'voiceMode': false,
        'activeProfile': _profileName() == 'your' ? null : _profileName(),
        if (_patientProfileId != null) 'patientProfileId': _patientProfileId,
        if (_conversationId != null) 'conversationId': _conversationId,
      };

  void _addMessage(
    String text,
    bool isUser, {
    String? responseType,
    Map<String, dynamic>? structuredData,
    List<Map<String, dynamic>>? sections,
    List<Map<String, dynamic>>? blocks,
    Map<String, dynamic>? safety,
    List<DocumentInfo>? documents,
    List<Map<String, dynamic>>? suggestedActions,
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
        blocks: blocks,
        safety: safety,
        documents: documents,
        suggestedActions: suggestedActions,
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
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? quickAction]) async {
    if (_isTyping || _isRestoring) return;
    final userMessage = (quickAction ?? _messageController.text).trim();
    if (userMessage.isEmpty) return;
    _messageController.clear();
    _addMessage(userMessage, true);
    setState(() {
      _isTyping = true;
      _processingLabel = _statusFor(userMessage);
    });

    final response = await AIService.sendMessage(
      prompt: userMessage,
      patientProfileId: _patientProfileId,
      conversationId: _conversationId,
      context: _requestContext(userMessage),
    );
    if (!mounted) return;
    setState(() => _isTyping = false);

    if (!response.success) {
      _addMessage(
        _safeError(response.message ?? response.reply),
        false,
      );
      return;
    }
    await _acceptResponse(response);
  }

  Future<void> _analyzeDocument(String documentId, String documentName) async {
    if (_isTyping || _isRestoring) return;
    final prompt = 'Please analyze $documentName in simple language.';
    _addMessage('Analyze $documentName', true);
    setState(() {
      _isTyping = true;
      _processingLabel = 'Analyzing the selected report…';
    });
    final response = await AIService.sendMessage(
      prompt: prompt,
      documentId: documentId,
      patientProfileId: _patientProfileId,
      conversationId: _conversationId,
      context: _requestContext(prompt),
    );
    if (!mounted) return;
    setState(() => _isTyping = false);
    if (!response.success) {
      _addMessage(_safeError(response.message ?? response.reply), false);
      return;
    }
    await _acceptResponse(response);
  }

  Future<void> _acceptResponse(AIResponse response) async {
    final responseContext = response.context ?? const <String, dynamic>{};
    final conversationId = responseContext['conversationId']?.toString();
    if (conversationId != null && conversationId.isNotEmpty) {
      _conversationId = conversationId;
      if (_patientProfileId != null) {
        await AIService.saveActiveConversationReference(
          patientProfileId: _patientProfileId!,
          conversationId: conversationId,
        );
      }
    }

    final lostPersonResults = response.responseType == 'lost_person_results'
        ? (response.items ?? response.data)
        : null;
    final documentRows = response.data
        ?.where((item) =>
            item['previewAvailable'] != null || item['documentId'] != null)
        .toList(growable: false);
    final documents = documentRows?.isNotEmpty == true && lostPersonResults == null
        ? documentRows!.map(DocumentInfo.fromJson).toList(growable: false)
        : null;
    _addMessage(
      response.reply,
      false,
      responseType: response.responseType,
      structuredData: response.structuredData,
      sections: response.sections,
      blocks: response.blocks,
      safety: response.safety,
      documents: documents,
      suggestedActions: response.suggestedActions,
      lostPersonResults: lostPersonResults,
    );
  }

  String _safeError(String value) {
    final text = value.trim();
    if (text.isEmpty || text.contains('Exception') || text.contains('http')) {
      return 'I could not complete that request. Please try again.';
    }
    return text;
  }

  Future<void> _startNewChat() async {
    if (_conversationId == null || _patientProfileId == null) {
      setState(() => _messages.clear());
      return;
    }
    final confirmed = await _confirm(
      title: 'Start a new conversation?',
      message: 'Your current conversation will no longer appear as the active chat.',
      confirm: 'Start new chat',
    );
    if (confirmed != true || !mounted) return;
    final succeeded = await AIService.startNewChat(
      conversationId: _conversationId!,
      patientProfileId: _patientProfileId!,
    );
    if (!mounted) return;
    if (!succeeded) {
      _showMessage('I could not start a new conversation. Please try again.');
      return;
    }
    setState(() {
      _messages.clear();
      _conversationId = null;
    });
  }

  Future<void> _clearChat() async {
    if (_conversationId == null || _patientProfileId == null) {
      setState(() => _messages.clear());
      return;
    }
    final confirmed = await _confirm(
      title: 'Clear current conversation?',
      message: 'This conversation will no longer appear as your active chat.',
      confirm: 'Clear conversation',
    );
    if (confirmed != true || !mounted) return;
    final succeeded = await AIService.clearActiveConversation(
      conversationId: _conversationId!,
      patientProfileId: _patientProfileId!,
    );
    if (!mounted) return;
    if (!succeeded) {
      _showMessage('I could not clear this conversation. Please try again.');
      return;
    }
    setState(() {
      _messages.clear();
      _conversationId = null;
    });
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirm,
  }) => showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirm),
            ),
          ],
        ),
      );

  void _showMessage(String value) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value)),
      );

  Future<void> _openPreview(DocumentInfo document) async {
    if (document.id.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DocumentPreviewScreen(
        documentId: document.id,
        documentName: document.name,
      ),
    ));
  }

  void _handleSuggestedAction(Map<String, dynamic> action) {
    final id = action['id']?.toString();
    final documentId = action['documentId']?.toString();
    if (id == 'preview_document' && documentId != null) {
      _openPreview(DocumentInfo(id: documentId, name: 'Medical document', type: 'Report', date: ''));
    } else if (id == 'analyze_document' && documentId != null) {
      _analyzeDocument(documentId, 'the selected report');
    } else if (id == 'compare_reports') {
      _sendMessage('Compare my two most recent reports');
    }
  }

  void _showComposerActions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Show available reports'),
              onTap: () {
                Navigator.pop(sheetContext);
                _sendMessage('Show my available reports');
              },
            ),
            ListTile(
              leading: const Icon(Icons.summarize_outlined),
              title: const Text('Summarize my latest report'),
              onTap: () {
                Navigator.pop(sheetContext);
                _sendMessage('Summarize my latest report');
              },
            ),
            ListTile(
              leading: const Icon(Icons.medication_outlined),
              title: const Text('Show current medicines'),
              onTap: () {
                Navigator.pop(sheetContext);
                _sendMessage('Show my current medicines');
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_note_outlined),
              title: const Text('Show upcoming appointments'),
              onTap: () {
                Navigator.pop(sheetContext);
                _sendMessage('Show my upcoming appointments');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedProfile =
        context.watch<ActivePatientProfileProvider>().activeProfile;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Medical AI Assistant',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            Text(
              selectedProfile == null ? _profileSubtitle() : 'Viewing ${selectedProfile.displayName}’s health records',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_ChatMenuAction>(
            tooltip: 'Conversation options',
            onSelected: (action) async {
              switch (action) {
                case _ChatMenuAction.newChat:
                  await _startNewChat();
                case _ChatMenuAction.continueChat:
                  await _loadActiveConversation(_observedProfileId);
                case _ChatMenuAction.clearChat:
                  await _clearChat();
                case _ChatMenuAction.privacy:
                  _showPrivacyDialog();
                case _ChatMenuAction.disclaimer:
                  _showDisclaimerDialog();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: _ChatMenuAction.newChat, child: Text('New chat')),
              PopupMenuItem(value: _ChatMenuAction.continueChat, child: Text('Continue active chat')),
              PopupMenuItem(value: _ChatMenuAction.clearChat, child: Text('Clear conversation')),
              PopupMenuDivider(),
              PopupMenuItem(value: _ChatMenuAction.privacy, child: Text('AI privacy information')),
              PopupMenuItem(value: _ChatMenuAction.disclaimer, child: Text('Medical disclaimer')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isRestoring) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Align(
          alignment: Alignment.topLeft,
          child: AiThinkingIndicator(phrases: ['Restoring your conversation…']),
        ),
      );
    }
    if (_messages.isEmpty) return _buildEmptyState();
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return AiThinkingIndicator(phrases: [_processingLabel]);
        }
        final message = _messages[index];
        final showAvatar = !message.isUser &&
            (index == 0 || _messages[index - 1].isUser);
        return RepaintBoundary(
          key: ValueKey('chat-${message.timestamp.microsecondsSinceEpoch}-$index'),
          child: _buildMessageBubble(message, showAssistantAvatar: showAvatar),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final name = _profileName() == 'your' ? 'there' : _profileName();
    final chips = <String>[
      'Summarize my latest report',
      'Show my available reports',
      'Explain a lab result',
      'Compare two reports',
      'Show current medicines',
      'Show upcoming appointments',
      'Summarize my health timeline',
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(Icons.health_and_safety_rounded,
                color: theme.colorScheme.onPrimaryContainer, size: 30),
          ),
          const SizedBox(height: 16),
          Text('Hello, $name', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('I can help you understand and organize your medical records.', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 6),
          Text(
            'I do not replace a qualified healthcare professional.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Text('Try asking', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.map((label) => ActionChip(
              label: Text(label),
              onPressed: () => _sendMessage(label),
            )).toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, {required bool showAssistantAvatar}) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final formattedTime = formatTimeForContext(context, message.timestamp, fallback: '');
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width * .80),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(5),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(message.text, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onPrimary)),
                if (formattedTime.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(formattedTime, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimary.withValues(alpha: .75))),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: showAssistantAvatar
                ? CircleAvatar(
                    radius: 15,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.health_and_safety_rounded,
                        size: 17, color: theme.colorScheme.onPrimaryContainer),
                  )
                : null,
          ),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width * .84 - 39),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AIMessageStructuredWidget(
                    text: message.text,
                    sections: message.sections,
                    blocks: message.blocks,
                    structuredData: message.structuredData,
                    responseType: message.responseType,
                    safety: message.safety,
                  ),
                  if (message.documents?.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Text('Source documents', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    ...message.documents!.map((document) => DocumentPreviewCard(
                      id: document.id,
                      name: document.name,
                      type: document.type,
                      date: document.date,
                      previewAvailable: document.previewAvailable,
                      onPreview: () => _openPreview(document),
                      onTap: () => _analyzeDocument(document.id, document.name),
                    )),
                  ],
                  if (message.suggestedActions?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: message.suggestedActions!.map((action) => OutlinedButton(
                        onPressed: () => _handleSuggestedAction(action),
                        child: Text(action['label']?.toString() ?? 'Continue'),
                      )).toList(growable: false),
                    ),
                  ],
                  if (message.lostPersonResults?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    ...message.lostPersonResults!.map((report) => _LostPersonChatCard(
                      report: report,
                      onTap: () {
                        final id = report['id']?.toString() ?? '';
                        if (id.isNotEmpty) {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => LostPersonDetailPage(reportId: id),
                          ));
                        }
                      },
                    )),
                  ],
                  if (formattedTime.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(formattedTime, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    final theme = Theme.of(context);
    final canSend = _messageController.text.trim().isNotEmpty && !_isTyping && !_isRestoring;
    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.dividerColor))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: _isTyping || _isRestoring ? null : _showComposerActions,
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Health record actions',
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                enabled: !_isTyping && !_isRestoring,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Ask about your health records',
                  counterText: '',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: canSend ? _sendMessage : null,
              icon: const Icon(Icons.send_rounded),
              tooltip: 'Send message',
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyDialog() => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('AI privacy information'),
          content: const Text('Your active conversation is scoped to the selected health profile and automatically expires after 48 hours of inactivity. Document previews use temporary, authorized links.'),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
        ),
      );

  void _showDisclaimerDialog() => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Medical disclaimer'),
          content: const Text('This assistant explains information from your records. It may make mistakes and does not diagnose conditions, prescribe treatment, or replace a qualified healthcare professional. Seek emergency care for urgent symptoms.'),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
        ),
      );
}

enum _ChatMenuAction { newChat, continueChat, clearChat, privacy, disclaimer }

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.responseType,
    this.structuredData,
    this.sections,
    this.blocks,
    this.safety,
    this.documents,
    this.suggestedActions,
    this.lostPersonResults,
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? responseType;
  final Map<String, dynamic>? structuredData;
  final List<Map<String, dynamic>>? sections;
  final List<Map<String, dynamic>>? blocks;
  final Map<String, dynamic>? safety;
  final List<DocumentInfo>? documents;
  final List<Map<String, dynamic>>? suggestedActions;
  final List<Map<String, dynamic>>? lostPersonResults;

  factory ChatMessage.fromServer(Map<String, dynamic> value) {
    final metadata = value['metadata'] is Map
        ? (value['metadata'] as Map).map((key, item) => MapEntry(key.toString(), item))
        : <String, dynamic>{};
    List<Map<String, dynamic>>? mapList(dynamic source) => source is List
        ? source.whereType<Map>().map((item) => item.map((key, value) => MapEntry(key.toString(), value))).toList(growable: false)
        : null;
    final data = mapList(metadata['data']);
    return ChatMessage(
      text: (value['content'] ?? '').toString(),
      isUser: value['role']?.toString().toLowerCase() == 'user',
      timestamp: DateTime.tryParse(value['timestamp']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      responseType: metadata['responseType']?.toString(),
      structuredData: metadata['structuredData'] is Map
          ? (metadata['structuredData'] as Map).map((key, item) => MapEntry(key.toString(), item))
          : null,
      sections: mapList(metadata['sections']),
      blocks: mapList(metadata['blocks']),
      safety: metadata['safety'] is Map
          ? (metadata['safety'] as Map).map((key, item) => MapEntry(key.toString(), item))
          : null,
      documents: data?.map(DocumentInfo.fromJson).toList(growable: false),
    );
  }
}

class _LostPersonChatCard extends StatelessWidget {
  const _LostPersonChatCard({required this.report, required this.onTap});

  final Map<String, dynamic> report;
  final VoidCallback onTap;

  String _value(String key, [String fallback = '']) {
    final value = report[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(top: 8),
        elevation: 0,
        child: ListTile(
          leading: const Icon(Icons.person_search_rounded),
          title: Text(_value('personName', 'Unnamed person'), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${_value('lastSeenLocation', 'Location unavailable')} • ${_value('status', 'open')}', maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}
