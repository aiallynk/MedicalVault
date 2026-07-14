import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../../api_service.dart';

class FamilyCareApiException implements Exception {
  final String message;
  final String? code;
  final int statusCode;
  final Map<String, String> fields;

  const FamilyCareApiException(
    this.message,
    this.statusCode, {
    this.code,
    this.fields = const {},
  });

  @override
  String toString() => message;
}

class FamilyCareApi {
  FamilyCareApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  String get _baseUrl => '${ApiService.baseUrl}/v1/family-care';

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) =>
      _send('POST', path, body: body, idempotencyKey: idempotencyKey);

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) =>
      _send('PATCH', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> getUser(String path) =>
      _send('GET', path, userScope: true);

  Future<Map<String, dynamic>> patchUser(
    String path,
    Map<String, dynamic> body,
  ) =>
      _send('PATCH', path, body: body, userScope: true);

  static String newIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
    bool userScope = false,
  }) async {
    final token = await ApiService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw const FamilyCareApiException('Please sign in again.', 401,
          code: 'AUTH_REQUIRED');
    }
    final baseUrl = userScope ? '${ApiService.baseUrl}/v1/users' : _baseUrl;
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll({
        HttpHeaders.authorizationHeader: 'Bearer $token',
        HttpHeaders.acceptHeader: 'application/json',
        HttpHeaders.contentTypeHeader: 'application/json',
        if (idempotencyKey?.trim().isNotEmpty == true)
          'Idempotency-Key': idempotencyKey!.trim(),
      });
    if (body != null) request.body = jsonEncode(body);
    final streamed =
        await _client.send(request).timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed);
    final payload = _decode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['success'] == false) {
      final error = _map(payload['error']);
      final rawFields = _map(error['fields']);
      throw FamilyCareApiException(
        (error['message'] ??
                payload['message'] ??
                'Family Care is temporarily unavailable.')
            .toString(),
        response.statusCode,
        code: (error['code'] ?? payload['code'])?.toString(),
        fields: rawFields.map((key, value) => MapEntry(key, value.toString())),
      );
    }
    return payload;
  }

  Map<String, dynamic> _decode(String raw) {
    try {
      return _map(jsonDecode(raw));
    } catch (_) {
      return const <String, dynamic>{};
    }
  }
}

Map<String, dynamic> _map(dynamic value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : <String, dynamic>{};
