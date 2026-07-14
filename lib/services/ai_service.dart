import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';

class AIResponse {
  final bool success;
  final String reply;
  final String language;
  final String responseType;
  final Map<String, dynamic>? structuredData;
  final List<Map<String, dynamic>>? sections;
  final Map<String, dynamic>? safety;
  final Map<String, dynamic>? context;
  final Map<String, dynamic>? documentMetadata;
  final List<Map<String, dynamic>>? data;
  final String? type;
  final String? title;
  final List<Map<String, dynamic>>? items;
  final List<Map<String, dynamic>>? blocks;
  final List<Map<String, dynamic>>? suggestedActions;
  final String? intent;
  final String? status;
  final String? message;

  AIResponse({
    required this.success,
    required this.reply,
    this.language = 'english',
    this.responseType = 'text',
    this.structuredData,
    this.sections,
    this.safety,
    this.context,
    this.documentMetadata,
    this.data,
    this.type,
    this.title,
    this.items,
    this.blocks,
    this.suggestedActions,
    this.intent,
    this.status,
    this.message,
  });

  factory AIResponse.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>>? parseMapList(dynamic value) {
      if (value is! List) return null;
      final parsed = value
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .toList(growable: false);
      return parsed.isEmpty ? null : parsed;
    }

    Map<String, dynamic>? parseMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    }

    return AIResponse(
      success: json['success'] ?? false,
      reply: (json['reply'] ?? json['message'] ?? '').toString(),
      language: json['language'] ?? 'english',
      responseType: json['responseType'] ?? 'text',
      structuredData: parseMap(json['structuredData']),
      sections: parseMapList(json['sections']),
      safety: parseMap(json['safety']),
      context: parseMap(json['context']),
      documentMetadata: parseMap(json['documentMetadata']),
      data: parseMapList(json['data']),
      type: json['type'],
      title: json['title'],
      items: parseMapList(json['items']),
      blocks: parseMapList(json['blocks']),
      suggestedActions: parseMapList(json['suggestedActions']),
      intent: json['intent']?.toString(),
      status: json['status']?.toString(),
      message: json['message'],
    );
  }
}

class DocumentInfo {
  final String id;
  final String name;
  final String date;
  final String type;
  final String? mimeType;
  final String? reportDate;
  final String? uploadedAt;
  final bool previewAvailable;
  final String? description;

  DocumentInfo({
    required this.id,
    required this.name,
    required this.date,
    required this.type,
    this.mimeType,
    this.reportDate,
    this.uploadedAt,
    this.previewAvailable = false,
    this.description,
  });

  factory DocumentInfo.fromJson(Map<String, dynamic> json) {
    return DocumentInfo(
      id: (json['documentId'] ?? json['id'] ?? '').toString(),
      name: (json['displayName'] ?? json['name'] ?? 'Medical document').toString(),
      date: (json['reportDate'] ?? json['uploadedAt'] ?? json['date'] ?? '').toString(),
      type: (json['documentType'] ?? json['type'] ?? 'Document').toString(),
      mimeType: (json['fileType'] ?? json['mimeType'])?.toString(),
      reportDate: json['reportDate']?.toString(),
      uploadedAt: json['uploadedAt']?.toString(),
      previewAvailable: json['previewAvailable'] == true,
      description: json['description'],
    );
  }
}

class AIService {
  static final Dio _dio = Dio();
  static const String model = 'gpt-4o';
  static const String _activeConversationPrefix =
      'ai_assistant_active_conversation_';

  /// Send a message to the AI assistant
  static Future<AIResponse> sendMessage({
    required String prompt,
    String? documentId,
    String? patientProfileId,
    String? conversationId,
    Map<String, dynamic>? context,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return AIResponse(
          success: false,
          reply:
              'Please log in to use the AI Assistant. You can log in from the Settings page.',
          message: 'No authentication token available',
        );
      }

      final response = await _dio.post(
        '${ApiService.baseUrl}/ai/ask',
        data: {
          'prompt': prompt,
          'model': model,
          if (documentId != null) 'documentId': documentId,
          if (patientProfileId != null && patientProfileId.trim().isNotEmpty)
            'patientProfileId': patientProfileId.trim(),
          if (conversationId != null && conversationId.trim().isNotEmpty)
            'conversationId': conversationId.trim(),
          if (context != null) 'context': context,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return AIResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to send message: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      String message = e.message ?? 'AI request failed';
      if (data is Map) {
        message = (data['message'] ?? data['error'] ?? message).toString();
      }
      return AIResponse(
        success: false,
        reply: message,
        message: message,
      );
    } catch (_) {
      return AIResponse(
        success: false,
        reply: 'Sorry, I encountered an error. Please try again.',
        message: 'AI request failed',
      );
    }
  }

  /// The backend is authoritative. The local ID is used only to keep a
  /// per-profile reference across app restarts; no cached message content is
  /// read from the device.
  static Future<Map<String, dynamic>?> getActiveConversation({
    String? patientProfileId,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return null;
      final response = await _dio.get(
        '${ApiService.baseUrl}/ai/conversations/active',
        queryParameters: {
          if (patientProfileId != null && patientProfileId.trim().isNotEmpty)
            'patientProfileId': patientProfileId.trim(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode != 200 || response.data is! Map) return null;
      final data = (response.data as Map)
          .map((key, value) => MapEntry(key.toString(), value));
      if (data['success'] != true) return null;
      final profile = data['patientProfile'];
      final profileId = profile is Map ? profile['id']?.toString() : patientProfileId;
      final conversationId = data['conversationId']?.toString();
      if (profileId != null && profileId.isNotEmpty) {
        if (conversationId != null && conversationId.isNotEmpty) {
          await _saveActiveConversationReference(profileId, conversationId);
        } else {
          await clearActiveConversationReference(profileId);
        }
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> startNewChat({
    required String conversationId,
    required String patientProfileId,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      final response = await _dio.post(
        '${ApiService.baseUrl}/ai/conversations/$conversationId/new',
        data: {'patientProfileId': patientProfileId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final success = response.statusCode == 200 && response.data is Map &&
          response.data['success'] == true;
      if (success) await clearActiveConversationReference(patientProfileId);
      return success;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> clearActiveConversation({
    required String conversationId,
    required String patientProfileId,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return false;
      final response = await _dio.delete(
        '${ApiService.baseUrl}/ai/conversations/$conversationId',
        queryParameters: {'patientProfileId': patientProfileId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final success = response.statusCode == 200 && response.data is Map &&
          response.data['success'] == true;
      if (success) await clearActiveConversationReference(patientProfileId);
      return success;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getPreviewUrl(String documentId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || documentId.trim().isEmpty) return null;
      final response = await _dio.get(
        '${ApiService.baseUrl}/files/${documentId.trim()}/preview-url',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode != 200 || response.data is! Map ||
          response.data['success'] != true) {
        return null;
      }
      return (response.data as Map)
          .map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveActiveConversationReference({
    required String patientProfileId,
    required String conversationId,
  }) => _saveActiveConversationReference(patientProfileId, conversationId);

  static Future<void> _saveActiveConversationReference(
    String patientProfileId,
    String conversationId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_activeConversationPrefix$patientProfileId', conversationId);
  }

  static Future<void> clearActiveConversationReference(String patientProfileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_activeConversationPrefix$patientProfileId');
  }

  static Future<void> clearAllActiveConversationReferences() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_activeConversationPrefix));
    await Future.wait(keys.map(prefs.remove));
  }

  /// Load persisted chat history for current authorized user scope.
  static Future<Map<String, dynamic>?> getChatHistory({
    String? patientId,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return null;
      }

      final response = await _dio.get(
        '${ApiService.baseUrl}/ai/chat',
        queryParameters: {
          if (patientId != null && patientId.trim().isNotEmpty)
            'patientId': patientId.trim(),
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data is Map
            ? (response.data as Map)
                .map((key, value) => MapEntry(key.toString(), value))
            : null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Clear persisted chat history for current authorized user scope.
  static Future<bool> clearChatHistory({
    String? patientId,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return false;
      }

      final response = await _dio.delete(
        '${ApiService.baseUrl}/ai/chat',
        queryParameters: {
          if (patientId != null && patientId.trim().isNotEmpty)
            'patientId': patientId.trim(),
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      return response.statusCode == 200 &&
          response.data is Map &&
          response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Get user documents for AI assistant
  static Future<List<DocumentInfo>> getUserDocuments() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return [];
      }

      final response = await _dio.get(
        '${ApiService.baseUrl}/ai/documents',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final documents = response.data['documents'] as List;
        return documents.map((doc) => DocumentInfo.fromJson(doc)).toList();
      } else {
        throw Exception('Failed to fetch documents');
      }
    } catch (_) {
      return [];
    }
  }

  /// Check AI service status
  static Future<bool> checkStatus() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return false;
      }

      final response = await _dio.get(
        '${ApiService.baseUrl}/ai/status',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      return response.statusCode == 200 && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Detect language from text
  static String detectLanguage(String text) {
    // Simple language detection based on character patterns
    final hindiPattern = RegExp(r'[\u0900-\u097F]');
    final englishPattern = RegExp(r'[a-zA-Z]');

    final hindiMatches = hindiPattern.allMatches(text).length;
    final englishMatches = englishPattern.allMatches(text).length;

    if (hindiMatches > englishMatches * 2) {
      return 'hindi';
    } else if (englishMatches > hindiMatches) {
      return 'english';
    } else {
      return 'hinglish'; // Mixed language
    }
  }

  /// Get language display name
  static String getLanguageDisplayName(String language) {
    switch (language) {
      case 'hindi':
        return 'हिंदी';
      case 'marathi':
        return 'मराठी';
      case 'hinglish':
        return 'Hinglish';
      case 'english':
      default:
        return 'English';
    }
  }

  /// Get supported languages
  static List<Map<String, String>> getSupportedLanguages() {
    return [
      {'code': 'english', 'name': 'English', 'flag': '🇺🇸'},
      {'code': 'hindi', 'name': 'हिंदी', 'flag': '🇮🇳'},
      {'code': 'marathi', 'name': 'मराठी', 'flag': '🇮🇳'},
      {'code': 'hinglish', 'name': 'Hinglish', 'flag': '🌍'},
    ];
  }
}
