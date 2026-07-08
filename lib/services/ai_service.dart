import 'package:dio/dio.dart';
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
      reply: json['reply'] ?? '',
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
      message: json['message'],
    );
  }
}

class DocumentInfo {
  final String id;
  final String name;
  final String date;
  final String type;
  final String? previewUrl;
  final String? description;

  DocumentInfo({
    required this.id,
    required this.name,
    required this.date,
    required this.type,
    this.previewUrl,
    this.description,
  });

  factory DocumentInfo.fromJson(Map<String, dynamic> json) {
    return DocumentInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      date: json['date'] ?? '',
      type: json['type'] ?? '',
      previewUrl: json['previewUrl'],
      description: json['description'],
    );
  }
}

class AIService {
  static final Dio _dio = Dio();
  static const String model = 'gpt-4o';

  /// Send a message to the AI assistant
  static Future<AIResponse> sendMessage({
    required String prompt,
    String? documentId,
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
    } catch (e) {
      print('AI Service Error: $e');
      return AIResponse(
        success: false,
        reply: 'Sorry, I encountered an error. Please try again.',
        message: e.toString(),
      );
    }
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
        print('No authentication token available for getUserDocuments');
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
    } catch (e) {
      print('Get Documents Error: $e');
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
    } catch (e) {
      print('AI Status Check Error: $e');
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
