import 'package:dio/dio.dart';
import '../api_service.dart';

class AIResponse {
  final bool success;
  final String reply;
  final String language;
  final String responseType;
  final Map<String, dynamic>? structuredData;
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
    this.documentMetadata,
    this.data,
    this.type,
    this.title,
    this.items,
    this.message,
  });

  factory AIResponse.fromJson(Map<String, dynamic> json) {
    return AIResponse(
      success: json['success'] ?? false,
      reply: json['reply'] ?? '',
      language: json['language'] ?? 'english',
      responseType: json['responseType'] ?? 'text',
      structuredData: json['structuredData'],
      documentMetadata: json['documentMetadata'],
      data: json['data'] != null
          ? List<Map<String, dynamic>>.from(json['data'])
          : null,
      type: json['type'],
      title: json['title'],
      items: json['items'] != null
          ? List<Map<String, dynamic>>.from(json['items'])
          : null,
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

  /// Send a message to the AI assistant
  static Future<AIResponse> sendMessage({
    required String prompt,
    String? documentId,
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
          if (documentId != null) 'documentId': documentId,
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
    } catch (e) {
      print('AI Service Error: $e');
      return AIResponse(
        success: false,
        reply: 'Sorry, I encountered an error. Please try again.',
        message: e.toString(),
      );
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
