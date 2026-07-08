import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:hello/Notifications/fcm_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import 'Document_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hello/helpers/google_auth_helper.dart';
import 'package:hello/services/offline/offline_storage_service.dart';
import 'package:hello/services/secure_token_storage.dart';

class DocumentUploadResult {
  final bool success;
  final Document? document;
  final String message;
  final String? code;
  final int? statusCode;
  final String verificationStatus;
  final String verificationReason;
  final String verificationMode;
  final int? processingTimeMs;

  const DocumentUploadResult({
    required this.success,
    this.document,
    this.message = '',
    this.code,
    this.statusCode,
    this.verificationStatus = '',
    this.verificationReason = '',
    this.verificationMode = '',
    this.processingTimeMs,
  });
}

class ApiService {
  static void _debugLog(String message) {
    if (!kReleaseMode) {
      // ignore: avoid_print
      print(message);
    }
  }

  static const String _defaultApiBaseUrl =
      "https://backend-medicalvault.onrender.com/api";

  // Base URL is read from the .env file (API_BASE_URL) at runtime, falling
  // back to --dart-define and finally to the hardcoded default above.
  static String get baseUrl => dotenv.env['API_BASE_URL']?.trim().isNotEmpty ==
          true
      ? dotenv.env['API_BASE_URL']!.trim()
      : const String.fromEnvironment("API_BASE_URL",
          defaultValue: _defaultApiBaseUrl);
  static String get authUrl => "$baseUrl/auth";
  static String get filesUrl => "$baseUrl/files";
  static String get qrUrl => "$baseUrl/qr";
  static String get aiUrl => "$baseUrl/ai";
  static String get sosUrl => "$baseUrl/sos";
  static String get lostFoundUrl => "$baseUrl/lost-found";
  static String get khojUrl => "$baseUrl/khoj";
  static String get patientAppointmentsUrl => "$baseUrl/patient/appointments";
  static String get publicUrl => "$baseUrl/public";

  static String get _apiOrigin {
    var parsed = Uri.tryParse(baseUrl) ?? Uri.parse(_defaultApiBaseUrl);
    if (parsed.host.isEmpty) {
      parsed = Uri.parse(_defaultApiBaseUrl);
    }
    final portPart = parsed.hasPort && parsed.port > 0 ? ":${parsed.port}" : "";
    return "${parsed.scheme}://${parsed.host}$portPart";
  }

  static String? resolveMediaUrl(String? rawUrl) {
    final value = rawUrl?.trim() ?? "";
    if (value.isEmpty) return null;

    if (value.startsWith("data:image/")) return value;

    final parsed = Uri.tryParse(value);
    if (parsed != null &&
        parsed.hasScheme &&
        (parsed.scheme == "http" || parsed.scheme == "https") &&
        parsed.host.isNotEmpty) {
      return value;
    }

    if (value.startsWith("/uploads/")) {
      return "$_apiOrigin$value";
    }
    if (value.startsWith("uploads/")) {
      return "$_apiOrigin/$value";
    }

    // Unknown relative keys (for example raw S3 keys) are intentionally ignored
    // so Flutter doesn't try to treat them as local file:// URIs.
    return null;
  }

  static const Duration _publicCacheTtl = Duration(minutes: 5);
  static const Duration _appointmentsCacheTtl = Duration(minutes: 3);
  static const Duration _publicGeoCacheTtl = Duration(minutes: 20);
  static const Duration _nearbyFreshnessTtl = Duration(hours: 24);
  static const Duration _documentsRequestTimeout = Duration(seconds: 12);
  static const int _lostPhotoSearchMaxBytes = 4 * 1024 * 1024;
  static const Set<String> _lostFoundPhotoMimeTypes = {
    'image/jpeg',
    'image/png',
  };
  static const String _docsCachePrefix = "docs_cache_v1_";
  static const String _groupedDocsCachePrefix = "grouped_docs_cache_v1_";
  static const String _publicGeoCountryKey = "public_geo_country";
  static const String _publicGeoStateKey = "public_geo_state";
  static const String _publicGeoRegionKey = "public_geo_region";
  static final Map<String, _TimedCacheEntry<List<Map<String, dynamic>>>>
      _adsCache = {};
  static _TimedCacheEntry<Map<String, dynamic>>? _uiConfigCache;
  static _TimedCacheEntry<List<dynamic>>? _pastAppointmentsCache;
  static _TimedCacheEntry<_PublicGeoScope>? _publicGeoScopeCache;
  static const Set<String> _forcedLogoutCodes = {
    "SESSION_INVALID",
    "USER_DISABLED",
    "TOKEN_VERSION_MISMATCH",
  };
  static const String _defaultSessionInvalidMessage =
      "You have been logged out due to login from another device";
  static const String _defaultUserDisabledMessage =
      "Your account has been deactivated by admin.";
  static const String _defaultSessionExpiredMessage =
      "Your session expired. Please log in again.";
  static const String _deviceIdPrefsKey = "auth_device_id";
  static final StreamController<Map<String, String>> _sessionEventsController =
      StreamController<Map<String, String>>.broadcast();
  static Future<bool>? _refreshInFlight;

  static Stream<Map<String, String>> get sessionEvents =>
      _sessionEventsController.stream;

  static void invalidatePublicConfigCache({
    bool ads = true,
    bool uiConfig = true,
  }) {
    if (ads) {
      _adsCache.clear();
    }
    if (uiConfig) {
      _uiConfigCache = null;
    }
  }

  static Uri publicConfigWebSocketUri({
    String platform = "APP",
    String? surface,
  }) {
    var parsedBase = Uri.tryParse(baseUrl) ?? Uri.parse(_defaultApiBaseUrl);
    if (parsedBase.host.isEmpty) {
      parsedBase = Uri.parse(_defaultApiBaseUrl);
    }

    final wsScheme = parsedBase.scheme == 'https' ? 'wss' : 'ws';
    final resolvedPort = parsedBase.hasPort && parsedBase.port > 0
        ? parsedBase.port
        : (wsScheme == 'wss' ? 443 : 80);
    final pathSegments = <String>[
      ...parsedBase.pathSegments.where((segment) => segment.isNotEmpty),
      'public',
      'ws',
    ];

    final uri = Uri(
      scheme: wsScheme,
      host: parsedBase.host,
      port: resolvedPort,
      pathSegments: pathSegments,
    );
    final query = <String, String>{
      "platform": platform.trim().toUpperCase(),
    };
    final normalizedSurface = (surface ?? "").trim().toUpperCase();
    if (normalizedSurface.isNotEmpty) {
      query["surface"] = normalizedSurface;
    }
    return uri.replace(queryParameters: query);
  }

  static Uri authSessionWebSocketUri({
    String? token,
    String? attemptToken,
    String? deviceId,
  }) {
    var parsedBase = Uri.tryParse(baseUrl) ?? Uri.parse(_defaultApiBaseUrl);
    if (parsedBase.host.isEmpty) {
      parsedBase = Uri.parse(_defaultApiBaseUrl);
    }

    final wsScheme = parsedBase.scheme == 'https' ? 'wss' : 'ws';
    final resolvedPort = parsedBase.hasPort && parsedBase.port > 0
        ? parsedBase.port
        : (wsScheme == 'wss' ? 443 : 80);
    final pathSegments = <String>[
      ...parsedBase.pathSegments.where((segment) => segment.isNotEmpty),
      'auth',
      'session',
      'ws',
    ];

    final query = <String, String>{};
    final normalizedToken = (token ?? '').trim();
    final normalizedAttemptToken = (attemptToken ?? '').trim();
    final normalizedDeviceId = (deviceId ?? '').trim();
    if (normalizedToken.isNotEmpty) {
      query['token'] = normalizedToken;
    } else if (normalizedAttemptToken.isNotEmpty) {
      query['attemptToken'] = normalizedAttemptToken;
    }
    if (normalizedDeviceId.isNotEmpty) {
      query['deviceId'] = normalizedDeviceId;
    }

    return Uri(
      scheme: wsScheme,
      host: parsedBase.host,
      port: resolvedPort,
      pathSegments: pathSegments,
      queryParameters: query.isEmpty ? null : query,
    );
  }

  static String _normalizeGeoPart(dynamic value, {int maxLength = 80}) {
    final normalized = (value ?? "").toString().trim().toUpperCase();
    if (normalized.isEmpty) return "";
    return normalized.substring(
        0, normalized.length > maxLength ? maxLength : normalized.length);
  }

  static _PublicGeoScope _extractGeoScopeFromUserData(
    Map<String, dynamic> userData,
  ) {
    String readValue(List<String> keys) {
      for (final key in keys) {
        final dynamic value = userData[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return "";
    }

    final nestedLocation = userData["location"];
    final locationMap = nestedLocation is Map
        ? nestedLocation.map(
            (key, value) => MapEntry(key.toString(), value),
          )
        : const <String, dynamic>{};

    String readFromNested(List<String> keys) {
      for (final key in keys) {
        final dynamic value = locationMap[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return "";
    }

    final countryValue =
        readValue(["country", "countryCode", "isoCountryCode"]);
    final stateValue = readValue(["state", "province", "administrativeArea"]);
    final regionValue = readValue(["region", "district", "city", "locality"]);

    final country = _normalizeGeoPart(
      countryValue.isNotEmpty
          ? countryValue
          : readFromNested(["country", "countryCode", "isoCountryCode"]),
    );
    final state = _normalizeGeoPart(
      stateValue.isNotEmpty
          ? stateValue
          : readFromNested(["state", "province", "administrativeArea"]),
    );
    final region = _normalizeGeoPart(
      regionValue.isNotEmpty
          ? regionValue
          : readFromNested(["region", "district", "city", "locality"]),
    );

    return _PublicGeoScope(
      country: country,
      state: state,
      region: region,
    );
  }

  static Future<_PublicGeoScope> _resolveDeviceGeoScope() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return const _PublicGeoScope.empty();

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return const _PublicGeoScope.empty();
      }

      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {
        position = null;
      }

      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          ).timeout(const Duration(seconds: 2));
        } catch (_) {
          return const _PublicGeoScope.empty();
        }
      }

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(
        const Duration(seconds: 3),
        onTimeout: () => const <Placemark>[],
      );
      if (placemarks.isEmpty) {
        return const _PublicGeoScope.empty();
      }

      final place = placemarks.first;
      final country = _normalizeGeoPart(
        (place.isoCountryCode ?? "").trim().isNotEmpty
            ? place.isoCountryCode
            : place.country,
      );
      final state = _normalizeGeoPart(place.administrativeArea);
      final region = _normalizeGeoPart(
        (place.subAdministrativeArea ?? "").trim().isNotEmpty
            ? place.subAdministrativeArea
            : (place.locality ?? place.subLocality),
      );

      return _PublicGeoScope(
        country: country,
        state: state,
        region: region,
      );
    } catch (_) {
      return const _PublicGeoScope.empty();
    }
  }

  static Future<void> _persistPublicGeoScope(
    SharedPreferences prefs,
    _PublicGeoScope scope,
  ) async {
    if (scope.country.isEmpty) {
      await prefs.remove(_publicGeoCountryKey);
    } else {
      await prefs.setString(_publicGeoCountryKey, scope.country);
    }
    if (scope.state.isEmpty) {
      await prefs.remove(_publicGeoStateKey);
    } else {
      await prefs.setString(_publicGeoStateKey, scope.state);
    }
    if (scope.region.isEmpty) {
      await prefs.remove(_publicGeoRegionKey);
    } else {
      await prefs.setString(_publicGeoRegionKey, scope.region);
    }
  }

  static Future<_PublicGeoScope> _resolvePublicGeoScope({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _publicGeoScopeCache != null &&
        _publicGeoScopeCache!.isValid) {
      return _publicGeoScopeCache!.value;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedScope = _PublicGeoScope(
      country: _normalizeGeoPart(prefs.getString(_publicGeoCountryKey)),
      state: _normalizeGeoPart(prefs.getString(_publicGeoStateKey)),
      region: _normalizeGeoPart(prefs.getString(_publicGeoRegionKey)),
    );

    var scope = storedScope;
    final rawUserData = prefs.getString("userData");
    if (rawUserData != null && rawUserData.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawUserData);
        if (decoded is Map) {
          final userMap = decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          final userScope = _extractGeoScopeFromUserData(userMap);
          scope = userScope.withFallback(scope);
        }
      } catch (_) {
        // Ignore malformed userData cache.
      }
    }

    final shouldResolveFromDevice = forceRefresh || scope.isEmpty;
    if (shouldResolveFromDevice) {
      final deviceScope = await _resolveDeviceGeoScope();
      if (!deviceScope.isEmpty) {
        scope = deviceScope.withFallback(scope);
      }
    }

    if (scope.country != storedScope.country ||
        scope.state != storedScope.state ||
        scope.region != storedScope.region) {
      await _persistPublicGeoScope(prefs, scope);
    }

    _publicGeoScopeCache = _TimedCacheEntry(
      value: scope,
      expiresAt: DateTime.now().add(_publicGeoCacheTtl),
    );
    return scope;
  }

  // ---------------- TOKEN ----------------
  static Future<String?> _getToken() async {
    return SecureTokenStorage.getToken();
  }

  // ✅ Public method to get token for Dio requests
  static Future<String?> getToken() async {
    return _getToken();
  }

  static Map<String, dynamic> _decodeJsonMap(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      // Ignore malformed JSON payloads.
    }
    return <String, dynamic>{};
  }

  static void _emitSessionEvent(Map<String, String> event) {
    if (_sessionEventsController.isClosed) return;
    _sessionEventsController.add(event);
  }

  static void _emitSessionInvalid([String? message]) {
    final resolvedMessage = (message ?? _defaultSessionInvalidMessage).trim();
    _emitSessionEvent({
      'type': 'session_invalid',
      'message': resolvedMessage.isEmpty
          ? _defaultSessionInvalidMessage
          : resolvedMessage,
    });
  }

  static String _resolveForcedLogoutMessage(Map<String, dynamic> payload) {
    final code = (payload['code'] ?? '').toString().trim().toUpperCase();
    final message = (payload['message'] ?? '').toString().trim();
    if (message.isNotEmpty) return message;
    if (code == 'USER_DISABLED') return _defaultUserDisabledMessage;
    return _defaultSessionInvalidMessage;
  }

  static bool _isSessionInvalidResponse(
    http.Response response,
    Map<String, dynamic> payload,
  ) {
    if (response.statusCode != 401 && response.statusCode != 403) return false;
    final code = (payload['code'] ?? '').toString().trim().toUpperCase();
    return _forcedLogoutCodes.contains(code);
  }

  static Future<String> _ensureDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = (prefs.getString(_deviceIdPrefsKey) ?? '').trim();
    if (existing.isNotEmpty) return existing;

    final generated =
        '${Platform.operatingSystem}-${DateTime.now().microsecondsSinceEpoch}';
    await prefs.setString(_deviceIdPrefsKey, generated);
    return generated;
  }

  static Future<String> getOrCreateDeviceId() async {
    return _ensureDeviceId();
  }

  static String _deviceInfo() {
    final os = Platform.operatingSystem;
    final version = Platform.operatingSystemVersion.replaceAll('\n', ' ');
    return '$os $version'.trim();
  }

  static Future<Map<String, String>> _deviceHeaders() async {
    final deviceId = await _ensureDeviceId();
    return <String, String>{
      'x-device-id': deviceId,
      'x-device-info': _deviceInfo(),
    };
  }

  static Future<http.Response> _sendAuthorizedRequestWithRetry(
    Future<http.Response> Function(Map<String, String> headers) sender,
  ) async {
    Map<String, String> headers = await _authHeaders();
    http.Response response = await sender(headers);
    Map<String, dynamic> payload = _decodeJsonMap(response.body);

    if (response.statusCode == 401 || response.statusCode == 403) {
      final refreshed = await _refreshAccessTokenIfPossible();
      if (refreshed) {
        headers = await _authHeaders();
        response = await sender(headers);
        payload = _decodeJsonMap(response.body);
      }
    }

    if (_isSessionInvalidResponse(response, payload)) {
      _emitSessionInvalid(_resolveForcedLogoutMessage(payload));
    }

    return response;
  }

  static Future<void> _persistAuthSessionPayload(
    Map<String, dynamic> payload,
  ) async {
    final token = extractTokenFromResponseData(payload);
    if (token == null || token.trim().isEmpty) return;
    final refreshToken = extractRefreshTokenFromResponseData(payload);

    final userRaw = payload['user'] ??
        (payload['data'] is Map ? payload['data']['user'] : null);
    final userMap = userRaw is Map
        ? userRaw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final user = _normalizeUserForClient(userMap);

    final prefs = await SharedPreferences.getInstance();
    await SecureTokenStorage.saveToken(token);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await SecureTokenStorage.saveRefreshToken(refreshToken);
    }
    if (user.isNotEmpty) {
      await prefs.setString(
        "userId",
        user['id']?.toString() ?? user['_id']?.toString() ?? "",
      );
      await prefs.setString("email", user['email']?.toString() ?? "");
      await prefs.setString("name", user['name']?.toString() ?? "Patient");
      await prefs.setString("userData", jsonEncode(user));
      if (user['emailVerified'] != null) {
        await prefs.setBool('emailVerified', user['emailVerified'] == true);
      }
      await OfflineStorageService.instance.cacheUserData(user);
      await OfflineStorageService.instance.cacheEmergencyContactsFromUserData(
        user,
      );
    }

    await FCMService().registerToken();
  }

  static String? extractTokenFromResponseData(Map<String, dynamic>? data) {
    if (data == null) return null;
    final direct = data['token']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final accessToken = data['accessToken']?.toString().trim();
    if (accessToken != null && accessToken.isNotEmpty) return accessToken;

    final nested = data['data'];
    if (nested is Map) {
      final nestedToken = nested['token']?.toString().trim();
      if (nestedToken != null && nestedToken.isNotEmpty) {
        return nestedToken;
      }
      final nestedAccess = nested['accessToken']?.toString().trim();
      if (nestedAccess != null && nestedAccess.isNotEmpty) {
        return nestedAccess;
      }
    }

    return null;
  }

  static String? extractRefreshTokenFromResponseData(
      Map<String, dynamic>? data) {
    if (data == null) return null;

    final direct = data['refreshToken']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final nested = data['data'];
    if (nested is Map) {
      final nestedToken = nested['refreshToken']?.toString().trim();
      if (nestedToken != null && nestedToken.isNotEmpty) {
        return nestedToken;
      }
    }

    return null;
  }

  // ---------------- PASSWORD FLOWS ----------------
  // ---------------- EMAIL VERIFICATION ----------------
  static Future<Map<String, dynamic>?> verifyEmailWithToken(
      String token) async {
    try {
      final res = await http.post(
        Uri.parse("$authUrl/verify"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"token": token}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (extractTokenFromResponseData(
              data is Map
                  ? data.map((key, value) => MapEntry(key.toString(), value))
                  : null,
            ) !=
            null) {
          await _persistAuthSessionPayload(
            data is Map
                ? data.map((key, value) => MapEntry(key.toString(), value))
                : <String, dynamic>{},
          );
        }
        // Persist updated user
        final prefs = await SharedPreferences.getInstance();
        final user = data['user'];
        if (user != null) {
          await prefs.setString("userData", jsonEncode(user));
          await prefs.setString("email", user['email']?.toString() ?? "");
        }
        return {"success": true, ...data};
      } else {
        return {
          "success": false,
          "message": jsonDecode(res.body)['message'] ?? 'Verification failed'
        };
      }
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  static Future<Map<String, dynamic>?> verifyEmailWithCode(
      {required String email, required String code}) async {
    try {
      final res = await http.post(
        Uri.parse("$authUrl/verify-code"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "code": code}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (extractTokenFromResponseData(
              data is Map
                  ? data.map((key, value) => MapEntry(key.toString(), value))
                  : null,
            ) !=
            null) {
          await _persistAuthSessionPayload(
            data is Map
                ? data.map((key, value) => MapEntry(key.toString(), value))
                : <String, dynamic>{},
          );
        }
        final prefs = await SharedPreferences.getInstance();
        final user = data['user'];
        if (user != null) {
          await prefs.setString("userData", jsonEncode(user));
          await prefs.setString("email", user['email']?.toString() ?? "");
        }
        return {"success": true, ...data};
      } else {
        return {
          "success": false,
          "message": jsonDecode(res.body)['message'] ?? 'Invalid code'
        };
      }
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  static Future<Map<String, dynamic>?> resendVerification(String email) async {
    try {
      final res = await http.post(
        Uri.parse("$authUrl/resend-verification"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return {"success": true, ...data};
      }
      return {"success": false, ...data};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  static Future<Map<String, dynamic>?> forgotPassword(String email) async {
    try {
      final res = await http.post(
        Uri.parse("$authUrl/forgot-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data;
      } else {
        _debugLog("Forgot password failed");
        return {"success": false, "message": "Failed to send reset email"};
      }
    } catch (e) {
      _debugLog("Forgot password error: $e");
      return {"success": false, "message": "Network error"};
    }
  }

  static Future<Map<String, dynamic>?> resetPassword(
      {required String token, required String newPassword}) async {
    try {
      final res = await http.post(
        Uri.parse("$authUrl/reset-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"token": token, "newPassword": newPassword}),
      );

      final data = jsonDecode(res.body);
      return data;
    } catch (e) {
      _debugLog("Reset password error: $e");
      return {"success": false, "message": "Network error"};
    }
  }

  static Future<Map<String, dynamic>?> changePassword(
      {required String oldPassword, required String newPassword}) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse("$authUrl/change-password"),
        headers: {...headers, "Content-Type": "application/json"},
        body: jsonEncode(
            {"oldPassword": oldPassword, "newPassword": newPassword}),
      );

      final data = jsonDecode(res.body);
      return data;
    } catch (e) {
      _debugLog("Change password error: $e");
      return {"success": false, "message": "Network error"};
    }
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    final deviceHeaders = await _deviceHeaders();
    if (token == null || token.trim().isEmpty) {
      return deviceHeaders;
    }
    return {
      ...deviceHeaders,
      HttpHeaders.authorizationHeader: 'Bearer $token',
    };
  }

  static Future<void> _persistUserSnapshotIfPresent(
    Map<String, dynamic> payload,
  ) async {
    final userRaw = payload['user'] ??
        (payload['data'] is Map ? payload['data']['user'] : null);
    if (userRaw is! Map) return;

    final user = _normalizeUserForClient(
      userRaw.map((key, value) => MapEntry(key.toString(), value)),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("userData", jsonEncode(user));
    await prefs.setString(
      "userId",
      user['id']?.toString() ?? user['_id']?.toString() ?? "",
    );
    await prefs.setString("email", user['email']?.toString() ?? "");
    await prefs.setString("name", user['name']?.toString() ?? "Patient");
    await OfflineStorageService.instance.cacheUserData(user);
    await OfflineStorageService.instance.cacheEmergencyContactsFromUserData(
      user,
    );
  }

  static Future<bool> _refreshAccessTokenIfPossible() async {
    final existing = _refreshInFlight;
    if (existing != null) return existing;

    final operation = () async {
      final refreshToken = await SecureTokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.trim().isEmpty) {
        return false;
      }

      try {
        final headers = await _deviceHeaders();
        final response = await http
            .post(
              Uri.parse("$authUrl/refresh"),
              headers: {
                ...headers,
                "Content-Type": "application/json",
              },
              body: jsonEncode({"refreshToken": refreshToken}),
            )
            .timeout(const Duration(seconds: 10));
        final data = _decodeJsonMap(response.body);

        if (response.statusCode == 200 && data['success'] != false) {
          final nextToken = extractTokenFromResponseData(data);
          if (nextToken == null || nextToken.trim().isEmpty) {
            return false;
          }
          await SecureTokenStorage.saveToken(nextToken);
          final nextRefresh = extractRefreshTokenFromResponseData(data);
          if (nextRefresh != null && nextRefresh.isNotEmpty) {
            await SecureTokenStorage.saveRefreshToken(nextRefresh);
          }
          await _persistUserSnapshotIfPresent(data);
          return true;
        }

        final unauthorized =
            response.statusCode == 401 || response.statusCode == 403;
        if (unauthorized || _isSessionInvalidResponse(response, data)) {
          await SecureTokenStorage.clearToken();
          final message = (data['message'] ?? _defaultSessionExpiredMessage)
              .toString()
              .trim();
          _emitSessionInvalid(
            message.isEmpty ? _defaultSessionExpiredMessage : message,
          );
        }
      } catch (error) {
        _debugLog("Token refresh failed: $error");
      }
      return false;
    }();

    _refreshInFlight = operation;
    try {
      return await operation;
    } finally {
      _refreshInFlight = null;
    }
  }

  static Map<String, dynamic> _asStringKeyMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, data) => MapEntry(key.toString(), data));
    }
    return <String, dynamic>{};
  }

  static bool _looksEncryptedBlob(dynamic value) {
    final raw = (value ?? '').toString().trim().toLowerCase();
    return raw.startsWith('enc:v');
  }

  static Map<String, dynamic> _normalizeUserForClient(
    Map<String, dynamic> source, {
    List<Map<String, dynamic>> fallbackEmergencyContacts = const [],
  }) {
    final user = Map<String, dynamic>.from(source);

    final emergencyRaw = user['emergencyContact'];
    if (emergencyRaw is Map) {
      final emergency =
          emergencyRaw.map((key, value) => MapEntry(key.toString(), value));
      final phoneCandidate = (emergency['phone'] ??
              emergency['mobile'] ??
              emergency['number'] ??
              '')
          .toString()
          .trim();

      String resolvedPhone = phoneCandidate;
      if (_looksEncryptedBlob(resolvedPhone) &&
          fallbackEmergencyContacts.isNotEmpty) {
        resolvedPhone =
            (fallbackEmergencyContacts.first['phone'] ?? '').toString().trim();
      }
      if (_looksEncryptedBlob(resolvedPhone)) {
        resolvedPhone = '';
      }

      if (resolvedPhone.isNotEmpty) {
        emergency['phone'] = resolvedPhone;
      } else {
        emergency['phone'] = '';
      }
      user['emergencyContact'] = emergency;
    }

    final mobile = (user['mobile'] ?? '').toString().trim();
    if (_looksEncryptedBlob(mobile)) {
      user['mobile'] = '';
    }

    final allergies = (user['allergies'] ?? '').toString().trim();
    if (_looksEncryptedBlob(allergies)) {
      user['allergies'] = '';
    }

    final aadhaar = (user['aadhaar'] ?? '').toString().trim();
    if (_looksEncryptedBlob(aadhaar)) {
      user['aadhaar'] = '';
    }

    return user;
  }

  static bool? _parseAllowMultipleSessionsValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = (value ?? '').toString().trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'on' ||
        normalized == 'enabled') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no' ||
        normalized == 'off' ||
        normalized == 'disabled') {
      return false;
    }
    return null;
  }

  static bool? _extractAllowMultipleSessionsFromResponse(
    Map<String, dynamic> data,
  ) {
    final direct =
        _parseAllowMultipleSessionsValue(data['allowMultipleSessions']);
    if (direct != null) return direct;

    final candidateRoots = <Map<String, dynamic>>[
      _asStringKeyMap(data['data']),
      _asStringKeyMap(data['policy']),
      _asStringKeyMap(data['sessionPolicy']),
      _asStringKeyMap(data['session']),
      _asStringKeyMap(data['user']),
    ];
    for (final root in candidateRoots) {
      if (root.isEmpty) continue;
      final parsed = _parseAllowMultipleSessionsValue(
        root['allowMultipleSessions'],
      );
      if (parsed != null) return parsed;
    }

    final dataRoot = _asStringKeyMap(data['data']);
    if (dataRoot.isNotEmpty) {
      final nested = <Map<String, dynamic>>[
        _asStringKeyMap(dataRoot['policy']),
        _asStringKeyMap(dataRoot['sessionPolicy']),
        _asStringKeyMap(dataRoot['session']),
        _asStringKeyMap(dataRoot['user']),
      ];
      for (final node in nested) {
        if (node.isEmpty) continue;
        final parsed = _parseAllowMultipleSessionsValue(
          node['allowMultipleSessions'],
        );
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static Future<void> _persistAllowMultipleSessionsInCache(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawUserData = prefs.getString("userData");
      if (rawUserData != null && rawUserData.trim().isNotEmpty) {
        final decoded = jsonDecode(rawUserData);
        if (decoded is Map) {
          final user =
              decoded.map((key, data) => MapEntry(key.toString(), data));
          user['allowMultipleSessions'] = value;
          await prefs.setString("userData", jsonEncode(user));
          await OfflineStorageService.instance.cacheUserData(user);
          return;
        }
      }
      await prefs.setString(
        "userData",
        jsonEncode(<String, dynamic>{'allowMultipleSessions': value}),
      );
    } catch (e) {
      _debugLog("persist allowMultipleSessions cache failed: $e");
    }
  }

  // ---------------- DEVICE SESSIONS ----------------
  static Future<List<Map<String, dynamic>>> fetchDeviceSessions() async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(
        Uri.parse("$baseUrl/sessions"),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['sessions'] is List) {
          return (data['sessions'] as List)
              .whereType<Map>()
              .map((entry) => entry.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ))
              .toList(growable: false);
        }
      }
    } catch (e) {
      _debugLog("fetchDeviceSessions error: $e");
    }
    return [];
  }

  static Future<Map<String, dynamic>> fetchSessionPolicy() async {
    try {
      final headers = await _authHeaders();
      final endpoints = <Uri>[
        Uri.parse("$authUrl/session/policy"),
      ];

      for (final uri in endpoints) {
        try {
          final res = await http.get(uri, headers: headers);
          if (res.statusCode < 200 || res.statusCode >= 300) {
            continue;
          }
          final data = _decodeJsonMap(res.body);
          final parsed = _extractAllowMultipleSessionsFromResponse(data);
          if (parsed != null) {
            await _persistAllowMultipleSessionsInCache(parsed);
            return {
              'success': true,
              'allowMultipleSessions': parsed,
            };
          }
        } catch (_) {
          // Try next endpoint.
        }
      }

      final profile = await me();
      final parsedFromProfile =
          _parseAllowMultipleSessionsValue(profile?['allowMultipleSessions']);
      if (parsedFromProfile != null) {
        await _persistAllowMultipleSessionsInCache(parsedFromProfile);
        return {
          'success': true,
          'allowMultipleSessions': parsedFromProfile,
        };
      }
    } catch (e) {
      _debugLog("fetchSessionPolicy error: $e");
    }
    return {
      'success': false,
      'message': 'Unable to fetch session policy',
    };
  }

  static Future<Map<String, dynamic>> updateSessionPolicy({
    required bool allowMultipleSessions,
  }) async {
    try {
      final headers = await _authHeaders();
      final payload = jsonEncode({
        'allowMultipleSessions': allowMultipleSessions,
      });

      final requestBuilders = <Future<http.Response> Function()>[
        () => http.put(
              Uri.parse("$authUrl/session/policy"),
              headers: {...headers, "Content-Type": "application/json"},
              body: payload,
            ),
        () => http.patch(
              Uri.parse("$authUrl/session/policy"),
              headers: {...headers, "Content-Type": "application/json"},
              body: payload,
            ),
      ];

      for (final request in requestBuilders) {
        try {
          final res = await request();
          if (res.statusCode < 200 || res.statusCode >= 300) continue;
          final data = _decodeJsonMap(res.body);
          final parsed = _extractAllowMultipleSessionsFromResponse(data) ??
              allowMultipleSessions;
          await _persistAllowMultipleSessionsInCache(parsed);
          return {
            'success': true,
            'allowMultipleSessions': parsed,
            ...data,
          };
        } catch (_) {
          // Try next endpoint.
        }
      }

      final profileUpdate = await updateProfile({
        'allowMultipleSessions': allowMultipleSessions,
      });
      if (profileUpdate != null && profileUpdate['success'] == true) {
        await _persistAllowMultipleSessionsInCache(allowMultipleSessions);
        return {
          'success': true,
          'allowMultipleSessions': allowMultipleSessions,
          ...profileUpdate,
        };
      }
    } catch (e) {
      _debugLog("updateSessionPolicy error: $e");
    }
    return {
      'success': false,
      'message': 'Unable to update session policy',
      'allowMultipleSessions': allowMultipleSessions,
    };
  }

  static Future<bool> logoutDeviceSession(String sessionId) async {
    try {
      final headers = await _authHeaders();
      final res = await http.delete(
        Uri.parse("$baseUrl/sessions/$sessionId"),
        headers: headers,
      );
      if (res.statusCode == 200) return true;
    } catch (e) {
      _debugLog("logoutDeviceSession error: $e");
    }
    return false;
  }

  static Future<bool> logoutAllDeviceSessions() async {
    try {
      final headers = await _authHeaders();
      final res = await http.delete(
        Uri.parse("$baseUrl/sessions"),
        headers: headers,
      );
      if (res.statusCode == 200) return true;
    } catch (e) {
      _debugLog("logoutAllDeviceSessions error: $e");
    }
    return false;
  }

  // ---------------- LOGIN ----------------
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final headers = await _deviceHeaders();
      final res = await http.post(
        Uri.parse("$authUrl/login"),
        headers: {
          ...headers,
          "Content-Type": "application/json",
        },
        body: jsonEncode({"email": email, "password": password}),
      );
      final data = _decodeJsonMap(res.body);

      if (res.statusCode == 200 && data['success'] != false) {
        await _persistAuthSessionPayload(data);
        return {
          'success': true,
          ...data,
          'statusCode': res.statusCode,
        };
      }

      if (_isSessionInvalidResponse(res, data)) {
        _emitSessionInvalid(data['message']?.toString());
      }

      return {
        'success': false,
        ...data,
        'statusCode': res.statusCode,
        'message': (data['message'] ?? 'Login failed').toString(),
      };
    } catch (e) {
      _debugLog("Login error: $e");
      return {
        'success': false,
        'message': 'Network error',
        'statusCode': 0,
      };
    }
  }

  static Future<Map<String, dynamic>> loginWithGoogleIdToken(
      String idToken) async {
    try {
      final headers = await _deviceHeaders();
      final res = await http.post(
        Uri.parse("$authUrl/google"),
        headers: {
          ...headers,
          "Content-Type": "application/json",
        },
        body: jsonEncode({"idToken": idToken}),
      );
      final data = _decodeJsonMap(res.body);

      if (res.statusCode == 200 && data['success'] != false) {
        await _persistAuthSessionPayload(data);
        return {
          'success': true,
          ...data,
          'statusCode': res.statusCode,
        };
      }

      if (_isSessionInvalidResponse(res, data)) {
        _emitSessionInvalid(data['message']?.toString());
      }

      return {
        'success': false,
        ...data,
        'statusCode': res.statusCode,
        'message': (data['message'] ?? 'Google login failed').toString(),
      };
    } catch (e) {
      _debugLog("Google login error: $e");
      return {
        'success': false,
        'message': 'Network error',
        'statusCode': 0,
      };
    }
  }

  static Future<bool> respondToLoginAttempt({
    required String loginAttemptId,
    required bool approve,
  }) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse("$authUrl/session/login-attempt/respond"),
        headers: {
          ...headers,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "loginAttemptId": loginAttemptId,
          "approve": approve,
        }),
      );
      final data = _decodeJsonMap(res.body);
      if (_isSessionInvalidResponse(res, data)) {
        _emitSessionInvalid(data['message']?.toString());
      }
      return res.statusCode >= 200 &&
          res.statusCode < 300 &&
          data['success'] == true;
    } catch (e) {
      _debugLog("respondToLoginAttempt error: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>> finalizePendingLogin({
    required String loginAttemptId,
    required String attemptToken,
  }) async {
    try {
      final headers = await _deviceHeaders();
      final res = await http.post(
        Uri.parse("$authUrl/session/login-attempt/finalize"),
        headers: {
          ...headers,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "loginAttemptId": loginAttemptId,
          "attemptToken": attemptToken,
        }),
      );
      final data = _decodeJsonMap(res.body);

      if (res.statusCode == 200 && data['success'] != false) {
        await _persistAuthSessionPayload(data);
        return {
          'success': true,
          ...data,
          'statusCode': res.statusCode,
        };
      }

      if (_isSessionInvalidResponse(res, data)) {
        _emitSessionInvalid(data['message']?.toString());
      }

      return {
        'success': false,
        ...data,
        'statusCode': res.statusCode,
        'message': (data['message'] ?? 'Failed to finalize login').toString(),
      };
    } catch (e) {
      _debugLog("finalizePendingLogin error: $e");
      return {
        'success': false,
        'message': 'Network error',
        'statusCode': 0,
      };
    }
  }

  static Future<bool> sendSessionHeartbeat() async {
    try {
      final token = await _getToken();
      if (token == null || token.trim().isEmpty) return false;

      Future<http.Response> send() async {
        final headers = await _authHeaders();
        return http.post(
          Uri.parse("$authUrl/session/heartbeat"),
          headers: headers,
        );
      }

      var res = await send();
      var data = _decodeJsonMap(res.body);
      if (res.statusCode == 401 || res.statusCode == 403) {
        final refreshed = await _refreshAccessTokenIfPossible();
        if (refreshed) {
          res = await send();
          data = _decodeJsonMap(res.body);
        }
      }

      if (_isSessionInvalidResponse(res, data)) {
        _emitSessionInvalid(data['message']?.toString());
      }
      return res.statusCode == 200 && data['success'] == true;
    } catch (e) {
      _debugLog("sendSessionHeartbeat error: $e");
      return false;
    }
  }

  // ---------------- PROFILE ----------------
  static Future<Map<String, dynamic>?> me() async {
    try {
      Future<http.Response> fetch() async {
        final headers = await _authHeaders();
        return http
            .get(Uri.parse("$authUrl/me"), headers: headers)
            .timeout(const Duration(seconds: 8));
      }

      var res = await fetch();
      var data = _decodeJsonMap(res.body);
      if (res.statusCode == 401 || res.statusCode == 403) {
        final refreshed = await _refreshAccessTokenIfPossible();
        if (refreshed) {
          res = await fetch();
          data = _decodeJsonMap(res.body);
        }
      }
      if (res.statusCode == 200) {
        final rawUser = data['data'] is Map
            ? (data['data']['user'] is Map
                ? (data['data']['user'] as Map)
                    .map((key, value) => MapEntry(key.toString(), value))
                : null)
            : null;
        final fallbackContacts =
            await OfflineStorageService.instance.getEmergencyContacts();
        final user = rawUser == null
            ? null
            : _normalizeUserForClient(
                rawUser,
                fallbackEmergencyContacts: fallbackContacts,
              );
        if (user != null) {
          await OfflineStorageService.instance.cacheUserData(user);
          await OfflineStorageService.instance
              .cacheEmergencyContactsFromUserData(
            user,
          );
        }
        return user;
      }
      if (_isSessionInvalidResponse(res, data)) {
        _emitSessionInvalid(data['message']?.toString());
        return null;
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        _emitSessionInvalid(
          (data['message'] ?? _defaultSessionExpiredMessage).toString(),
        );
        _debugLog("Profile fetch denied: ${res.statusCode}");
        return null;
      }
      _debugLog("Profile fetch failed: ${res.body}");
      return OfflineStorageService.instance.getCachedUserData();
    } catch (e) {
      _debugLog("Me error: $e");
      return OfflineStorageService.instance.getCachedUserData();
    }
  }

  static Future<Map<String, dynamic>?> updateProfile(
      Map<String, dynamic> updates) async {
    try {
      final pendingEmergencyContacts =
          OfflineStorageService.extractEmergencyContacts(updates);
      if (pendingEmergencyContacts.isNotEmpty) {
        // Preserve plain emergency contacts locally even if backend echoes encrypted blobs.
        await OfflineStorageService.instance
            .cacheEmergencyContacts(pendingEmergencyContacts);
      }

      final headers = await _authHeaders();
      final res = await http.put(
        Uri.parse("$authUrl/me"),
        headers: {...headers, "Content-Type": "application/json"},
        body: jsonEncode(_sanitizeBody(updates)),
      );
      final data = _decodeJsonMap(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        final rawUserData = data['data'] is Map
            ? (data['data'] as Map)
                .map((key, value) => MapEntry(key.toString(), value))
            : null;
        if (rawUserData != null) {
          final userData = _normalizeUserForClient(
            rawUserData,
            fallbackEmergencyContacts: pendingEmergencyContacts,
          );

          final allergiesRaw = (userData['allergies'] ?? '').toString().trim();
          if (allergiesRaw.toLowerCase().startsWith('enc:v') &&
              updates['allergies'] is String) {
            userData['allergies'] = updates['allergies'];
          }

          final emergencyContactRaw = userData['emergencyContact'];
          if (emergencyContactRaw is Map) {
            final emergencyContact =
                emergencyContactRaw.map((k, v) => MapEntry(k.toString(), v));
            final phoneRaw =
                (emergencyContact['phone'] ?? '').toString().trim();
            if (phoneRaw.toLowerCase().startsWith('enc:v') &&
                pendingEmergencyContacts.isNotEmpty) {
              final first = pendingEmergencyContacts.first;
              emergencyContact['phone'] = first['phone'];
              if ((emergencyContact['name'] ?? '').toString().trim().isEmpty) {
                emergencyContact['name'] = first['name'];
              }
              if ((emergencyContact['relationship'] ?? '')
                  .toString()
                  .trim()
                  .isEmpty) {
                emergencyContact['relationship'] = first['relationship'];
              }
              userData['emergencyContact'] = emergencyContact;
            }
          }

          await prefs.setString('userData', jsonEncode(userData));
          if (userData['name'] != null) {
            await prefs.setString('name', userData['name'].toString());
          }
          if (userData['email'] != null) {
            await prefs.setString('email', userData['email'].toString());
          }
          await OfflineStorageService.instance.cacheUserData(userData);
          await OfflineStorageService.instance
              .cacheEmergencyContactsFromUserData(userData);

          // Keep return payload aligned with normalized data used by UI.
          data['data'] = userData;
        }
      }
      return data;
    } catch (e) {
      print("updateProfile error: $e");
      return {"success": false, "message": "Network error"};
    }
  }

  // ---------------- UPLOAD ----------------
  static Future<Document?> uploadDocument({
    required File file,
    required String title,
    required String category,
    String? notes,
    String? date,
    Function(double)? onProgress,
  }) async {
    final result = await uploadDocumentDetailed(
      file: file,
      title: title,
      category: category,
      notes: notes,
      date: date,
      onProgress: onProgress,
    );
    return result.success ? result.document : null;
  }

  static Future<DocumentUploadResult> uploadDocumentDetailed({
    required File file,
    required String title,
    String? category,
    String? notes,
    String? date,
    Function(double)? onProgress,
  }) async {
    try {
      // If category is omitted, backend auto-detects it after verification.
      final rawCategory = (category ?? "").toLowerCase().trim();
      String? normalizedCategory;
      if (rawCategory.contains("report")) {
        normalizedCategory = "Report";
      } else if (rawCategory.contains("prescription")) {
        normalizedCategory = "Prescription";
      } else if (rawCategory.contains("bill")) {
        normalizedCategory = "Bill";
      } else if (rawCategory.contains("insurance")) {
        normalizedCategory = "Insurance";
      }

      // Get authentication token
      final token = await _getToken();
      if (token == null || token.trim().isEmpty) {
        return const DocumentUploadResult(
          success: false,
          message: 'Login expired. Please sign in again.',
          code: 'LOGIN_EXPIRED',
          statusCode: 401,
        );
      }

      // Create Dio instance
      final dio = Dio();

      // Set up headers
      final headers = <String, dynamic>{
        HttpHeaders.authorizationHeader: 'Bearer $token',
      };

      // ✅ Detect MIME type by file extension
      String filename = file.path.replaceAll('\\', '/').split('/').last;
      final lowerName = filename.toLowerCase();
      String mimeType = _detectMimeType(lowerName);
      const allowedUploadMimeTypes = {
        'application/pdf',
        'image/jpeg',
        'image/png',
      };
      if (!allowedUploadMimeTypes.contains(mimeType)) {
        _debugLog('Unsupported upload file type: $mimeType');
        return const DocumentUploadResult(
          success: false,
          message: 'Only PDF, JPG, and PNG files are supported.',
        );
      }

      // Get file size for progress tracking
      final fileSize = await file.length();
      const maxUploadBytes = 50 * 1024 * 1024;
      if (fileSize > maxUploadBytes) {
        return const DocumentUploadResult(
          success: false,
          message: 'File too large',
          code: 'FILE_TOO_LARGE',
          statusCode: 400,
        );
      }

      // Notify initial progress (0%)
      if (onProgress != null) {
        onProgress(0.0);
      }

      // Use stream-based approach for better progress tracking
      final multipartFile = MultipartFile.fromStream(
        () => file.openRead(),
        fileSize,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      );

      // Prepare form data
      final formData = FormData.fromMap({
        'file': multipartFile,
        'title': title,
        if (normalizedCategory != null) 'category': normalizedCategory,
        if (notes != null) 'notes': notes,
        if (date != null) 'date': date,
      });

      // Track last reported progress to avoid too frequent updates
      double lastReportedProgress = 0.0;

      // Make the upload request with real progress tracking
      final response = await dio.post(
        "$filesUrl/upload",
        data: formData,
        options: Options(
          headers: headers,
          sendTimeout: const Duration(minutes: 5), // 5 minute timeout
          receiveTimeout: const Duration(minutes: 5),
          followRedirects: false,
          validateStatus: (status) => status! < 500,
        ),
        onSendProgress: (sent, total) {
          // This provides REAL upload progress
          if (onProgress != null && total > 0) {
            final progress = (sent / total) * 100;
            // Only update if progress changed by at least 0.5% to avoid too frequent updates
            // But always update for significant milestones (0%, 25%, 50%, 75%, 100%)
            if ((progress - lastReportedProgress).abs() >= 0.5 ||
                progress == 0.0 ||
                progress >= 25.0 && lastReportedProgress < 25.0 ||
                progress >= 50.0 && lastReportedProgress < 50.0 ||
                progress >= 75.0 && lastReportedProgress < 75.0 ||
                progress >= 100.0) {
              onProgress(progress.clamp(0.0, 100.0));
              lastReportedProgress = progress;
              // Debug print to verify progress is being tracked
              _debugLog(
                  "📤 Upload progress: ${progress.toStringAsFixed(2)}% ($sent/$total bytes)");
            }
          }
        },
      );

      if ((response.statusCode ?? 0) >= 200 &&
          (response.statusCode ?? 0) < 300) {
        final json = response.data;
        return DocumentUploadResult(
          success: true,
          document: Document.fromApi(json['document']),
          message: _extractApiMessage(json, fallback: 'Upload complete'),
          statusCode: response.statusCode,
          verificationStatus: (json['verificationStatus'] ?? '').toString(),
          verificationReason: (json['verificationReason'] ?? '').toString(),
          verificationMode: (json['verificationMode'] ?? '').toString(),
          processingTimeMs: json['processingTimeMs'] is num
              ? (json['processingTimeMs'] as num).round()
              : int.tryParse((json['processingTimeMs'] ?? '').toString()),
        );
      } else {
        _debugLog("Upload failed: ${response.data}");
        final payload = _responseDataAsMap(response.data);
        return DocumentUploadResult(
          success: false,
          message: _friendlyUploadMessage(
            payload,
            statusCode: response.statusCode,
          ),
          code: (payload['errorCode'] ?? payload['code'])?.toString(),
          statusCode: response.statusCode,
          verificationStatus: (payload['verificationStatus'] ?? '').toString(),
          verificationReason: (payload['verificationReason'] ?? '').toString(),
          verificationMode: (payload['verificationMode'] ?? '').toString(),
          processingTimeMs: payload['processingTimeMs'] is num
              ? (payload['processingTimeMs'] as num).round()
              : int.tryParse((payload['processingTimeMs'] ?? '').toString()),
        );
      }
    } on DioException catch (e) {
      final payload = _responseDataAsMap(e.response?.data);
      final message = _friendlyUploadMessage(
        payload,
        statusCode: e.response?.statusCode,
        fallback: e.message ?? 'Upload failed, please try again',
      );
      _debugLog("Upload error: $message");
      return DocumentUploadResult(
        success: false,
        message: message,
        code: (payload['errorCode'] ?? payload['code'])?.toString(),
        statusCode: e.response?.statusCode,
        verificationStatus: (payload['verificationStatus'] ?? '').toString(),
        verificationReason: (payload['verificationReason'] ?? '').toString(),
        verificationMode: (payload['verificationMode'] ?? '').toString(),
        processingTimeMs: payload['processingTimeMs'] is num
            ? (payload['processingTimeMs'] as num).round()
            : int.tryParse((payload['processingTimeMs'] ?? '').toString()),
      );
    } catch (e) {
      _debugLog("Upload error: $e");
      return DocumentUploadResult(
        success: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  static Map<String, dynamic> _responseDataAsMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return _decodeJsonMap(raw);
    }
    return <String, dynamic>{};
  }

  static String _extractApiMessage(
    dynamic raw, {
    String fallback = 'Request failed',
  }) {
    final payload = _responseDataAsMap(raw);
    for (final key in const ['message', 'msg', 'error']) {
      final value = payload[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    final nested = payload['data'];
    if (nested is Map) {
      for (final key in const ['message', 'msg', 'error']) {
        final value = nested[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return fallback;
  }

  static String _friendlyUploadMessage(
    dynamic raw, {
    int? statusCode,
    String fallback = 'Upload failed, please try again',
  }) {
    final payload = _responseDataAsMap(raw);
    final code = (payload['errorCode'] ?? payload['code'] ?? payload['error'])
        ?.toString()
        .trim()
        .toUpperCase();

    switch (code) {
      case 'FILE_TOO_LARGE':
        return 'File too large';
      case 'UNSUPPORTED_FILE_TYPE':
        return 'Unsupported file type';
      case 'LOGIN_EXPIRED':
      case 'AUTH_REQUIRED':
      case 'INVALID_TOKEN':
      case 'TOKEN_EXPIRED':
        return 'Login expired. Please sign in again.';
      case 'STORAGE_NOT_CONFIGURED':
        return 'Storage not configured';
      case 'NO_FILE_UPLOADED':
        return 'No file uploaded';
      case 'MISSING_PATIENT_ID':
        return 'Patient information is missing';
      case 'DOCUMENT_NOT_MEDICAL':
        return _extractApiMessage(
          payload,
          fallback:
              'Only medical-related documents are allowed. Please upload valid reports, prescriptions, or health records.',
        );
    }

    if (statusCode == 401) return 'Login expired. Please sign in again.';
    if (statusCode == 413) return 'File too large';
    if (statusCode == 503) return 'Storage not configured';

    return _extractApiMessage(payload, fallback: fallback);
  }

  // ---------------- MIME TYPE HELPERS ----------------
  static String _detectMimeType(String filename) {
    final ext =
        filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'json':
        return 'application/json';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default:
        return 'application/octet-stream';
    }
  }

  // ---------------- LOST & FOUND ----------------
  static Future<Map<String, dynamic>?> uploadProfilePhoto(File file) async {
    try {
      final token = await _getToken();
      final dio = Dio();
      final filename = file.path.split("/").last;
      final mimeType = _detectMimeType(filename.toLowerCase());
      final formData = FormData.fromMap({
        "photo": await MultipartFile.fromFile(
          file.path,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
      });

      final response = await dio.post(
        "$authUrl/profile-picture",
        data: formData,
        options: Options(
          headers: {
            if (token != null) HttpHeaders.authorizationHeader: "Bearer $token",
            "Content-Type": "multipart/form-data",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final rawUser = data?['data']?['user'];
        final user = rawUser is Map
            ? _normalizeUserForClient(
                rawUser.map((key, value) => MapEntry(key.toString(), value)),
              )
            : null;
        if (user != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userData', jsonEncode(user));
          if (user['name'] != null) {
            await prefs.setString('name', user['name'].toString());
          }
          if (user['email'] != null) {
            await prefs.setString('email', user['email'].toString());
          }
        }
        return data;
      }

      return response.data;
    } catch (e) {
      print("uploadProfilePhoto error: $e");
      return {"success": false, "message": "Network error"};
    }
  }

  static Future<String?> uploadLostFoundPhoto(File file) async {
    try {
      final token = await _getToken();
      if (token == null || token.trim().isEmpty) {
        throw Exception('Please log in again before uploading a photo.');
      }
      final dio = Dio();
      final filename = file.path.split("/").last;
      final mimeType = _detectMimeType(filename.toLowerCase());
      if (!_lostFoundPhotoMimeTypes.contains(mimeType)) {
        throw Exception('Only JPG and PNG photos are allowed.');
      }
      final fileSize = await file.length();
      if (fileSize <= 0) {
        throw Exception('Please choose a valid photo.');
      }
      final formData = FormData.fromMap({
        "photo": await MultipartFile.fromFile(
          file.path,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
      });

      final response = await dio.post(
        "$lostFoundUrl/upload-photo",
        data: formData,
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: "Bearer $token",
          },
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 201) {
        return response.data?["data"]?["photoUrl"]?.toString();
      }

      final payload = _responseDataAsMap(response.data);
      throw Exception(
          _extractApiMessage(payload, fallback: 'Photo upload failed'));
    } on DioException catch (e) {
      final payload = _responseDataAsMap(e.response?.data);
      throw Exception(
        _extractApiMessage(
          payload,
          fallback: e.message ?? 'Photo upload failed',
        ),
      );
    } catch (e) {
      _debugLog("uploadLostFoundPhoto error: $e");
      rethrow;
    }
  }

  static Map<String, dynamic> _sanitizeBody(Map<String, dynamic> body) {
    final sanitized = <String, dynamic>{};
    body.forEach((key, value) {
      if (value != null) {
        sanitized[key] = value;
      }
    });
    return sanitized;
  }

  static Future<Map<String, dynamic>> createLostPersonReport(
      Map<String, dynamic> body) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse("$lostFoundUrl/lost"),
      headers: {
        ...headers,
        "Content-Type": "application/json",
      },
      body: jsonEncode(_sanitizeBody(body)),
    );

    final decoded = _decodeJsonMap(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractApiMessage(decoded,
          fallback: 'Failed to create lost person report'));
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> createFoundPersonReport(
      Map<String, dynamic> body) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse("$lostFoundUrl/found"),
      headers: {
        ...headers,
        "Content-Type": "application/json",
      },
      body: jsonEncode(_sanitizeBody(body)),
    );

    final decoded = _decodeJsonMap(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractApiMessage(decoded,
          fallback: 'Failed to create found person report'));
    }
    return decoded;
  }

  /// Lightweight name typeahead for the "report found person" form.
  /// Returns up to 8 matching names from open missing-person reports.
  static Future<List<String>> searchLostPersonNameSuggestions(
    String query,
  ) async {
    final q = query.trim();
    if (q.length < 2) return const <String>[];
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse("$lostFoundUrl/name-suggestions")
          .replace(queryParameters: {"q": q});
      final res = await http.get(uri, headers: headers);
      if (res.statusCode != 200) return const <String>[];
      final decoded = _decodeJsonMap(res.body);
      final raw = decoded["data"]?["suggestions"];
      if (raw is! List) return const <String>[];
      return raw
          .map((entry) => entry.toString().trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      // Suggestions are a convenience — never block typing on failure.
      return const <String>[];
    }
  }

  static Future<List<dynamic>> fetchMyLostReports() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse("$lostFoundUrl/my-lost-reports"),
      headers: headers,
    );

    if (res.statusCode == 200) {
      final decoded = _decodeJsonMap(res.body);
      return decoded["data"]?["reports"] as List<dynamic>? ?? [];
    }
    final decoded = _decodeJsonMap(res.body);
    throw Exception(_extractApiMessage(decoded,
        fallback: 'Failed to fetch lost person reports'));
  }

  /// Search open lost-person reports (privacy-safe). Backend returns only
  /// non-sensitive fields; contact is masked unless the report allows it.
  static Future<List<dynamic>> searchLostPersons({
    String? query,
    int? age,
    String? gender,
    String? location,
    double? lat,
    double? lng,
    double? radiusKm,
    String? dateFrom,
    String? dateTo,
  }) async {
    final headers = await _authHeaders();
    final params = <String, String>{};
    if (query != null && query.trim().isNotEmpty) params['q'] = query.trim();
    if (age != null) params['age'] = age.toString();
    if (gender != null && gender.trim().isNotEmpty)
      params['gender'] = gender.trim();
    if (location != null && location.trim().isNotEmpty) {
      params['location'] = location.trim();
    }
    if (lat != null) params['lat'] = lat.toString();
    if (lng != null) params['lng'] = lng.toString();
    if (radiusKm != null) params['radiusKm'] = radiusKm.toString();
    if (dateFrom != null && dateFrom.isNotEmpty) params['dateFrom'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) params['dateTo'] = dateTo;

    final uri =
        Uri.parse("$lostFoundUrl/search").replace(queryParameters: params);
    final res = await http.get(uri, headers: headers);

    if (res.statusCode == 200) {
      final decoded = _decodeJsonMap(res.body);
      return decoded["data"]?["results"] as List<dynamic>? ?? [];
    }
    final decoded = _decodeJsonMap(res.body);
    throw Exception(
        _extractApiMessage(decoded, fallback: 'Failed to search lost persons'));
  }

  static Future<Map<String, dynamic>> searchLostPersonsWithPhoto({
    required File photo,
    String? query,
    int? age,
    String? gender,
    String? location,
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    final token = await _getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please log in again before searching with a photo.');
    }

    final dio = Dio();
    final filename = photo.path.split("/").last;
    final mimeType = _detectMimeType(filename.toLowerCase());
    if (!_lostFoundPhotoMimeTypes.contains(mimeType)) {
      throw Exception('Only JPG and PNG photos are allowed for photo search.');
    }
    final fileSize = await photo.length();
    if (fileSize <= 0) {
      throw Exception('Please choose a valid photo for search.');
    }
    if (fileSize > _lostPhotoSearchMaxBytes) {
      throw Exception(
          'Photo is too large. Please choose a JPG or PNG under 4 MB.');
    }

    final formData = FormData.fromMap({
      "photo": await MultipartFile.fromFile(
        photo.path,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ),
      if (query != null && query.trim().isNotEmpty) "q": query.trim(),
      if (age != null) "age": age.toString(),
      if (gender != null && gender.trim().isNotEmpty) "gender": gender.trim(),
      if (location != null && location.trim().isNotEmpty)
        "location": location.trim(),
      if (lat != null) "lat": lat.toString(),
      if (lng != null) "lng": lng.toString(),
      if (radiusKm != null) "radiusKm": radiusKm.toString(),
    });

    try {
      final response = await dio.post(
        "$lostFoundUrl/search-photo",
        data: formData,
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: "Bearer $token",
          },
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final payload = _responseDataAsMap(response.data);
      if ((response.statusCode ?? 0) >= 200 &&
          (response.statusCode ?? 0) < 300 &&
          payload['success'] == true) {
        return payload;
      }
      if (response.statusCode == 429) {
        throw Exception(
          _extractApiMessage(
            payload,
            fallback: 'Photo search is rate limited. Please try again later.',
          ),
        );
      }
      throw Exception(
        _extractApiMessage(payload, fallback: 'Failed to search by photo'),
      );
    } on DioException catch (e) {
      final payload = _responseDataAsMap(e.response?.data);
      throw Exception(
        _extractApiMessage(
          payload,
          fallback: e.message ?? 'Failed to search by photo',
        ),
      );
    }
  }

  /// Fetch a single lost-person report's privacy-safe detail by id.
  static Future<Map<String, dynamic>> getLostPersonDetail(String id) async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse("$lostFoundUrl/lost/$id"),
      headers: headers,
    );

    final decoded = _decodeJsonMap(res.body);
    if (res.statusCode == 200) {
      final report = decoded["data"]?["report"];
      if (report is Map) {
        return report.map((k, v) => MapEntry(k.toString(), v));
      }
      return <String, dynamic>{};
    }
    throw Exception(_extractApiMessage(decoded,
        fallback: 'Failed to load lost person details'));
  }

  /// Update the authenticated user's opt-in last known location. Used to power
  /// nearby lost-person alerts. Never called in a battery-draining loop.
  static Future<bool> updateUserLocation({
    double? lat,
    double? lng,
    String? address,
    bool? locationSharingEnabled,
    bool? lostPersonAlertsOptOut,
  }) async {
    try {
      final headers = await _authHeaders();
      final body = <String, dynamic>{};
      if (lat != null) body['lat'] = lat;
      if (lng != null) body['lng'] = lng;
      if (address != null) body['address'] = address;
      if (locationSharingEnabled != null) {
        body['locationSharingEnabled'] = locationSharingEnabled;
      }
      if (lostPersonAlertsOptOut != null) {
        body['lostPersonAlertsOptOut'] = lostPersonAlertsOptOut;
      }
      if (body.isEmpty) return false;

      final res = await http.put(
        Uri.parse("$baseUrl/users/location"),
        headers: {...headers, "Content-Type": "application/json"},
        body: jsonEncode(body),
      );
      return res.statusCode == 200;
    } catch (e) {
      _debugLog("updateUserLocation error: $e");
      return false;
    }
  }

  // ---------------- FETCH FILES ----------------
  static String _normalizeUserCacheId(String userId) => userId.trim();

  static String _docsCacheKey(String userId) =>
      "$_docsCachePrefix${_normalizeUserCacheId(userId)}";

  static String _groupedDocsCacheKey(String userId) =>
      "$_groupedDocsCachePrefix${_normalizeUserCacheId(userId)}";

  static List<Document> _documentsFromDynamicList(dynamic rawList) {
    if (rawList is! List) return const <Document>[];
    return rawList
        .whereType<Map>()
        .map((entry) => Document.fromApi(Map<String, dynamic>.from(entry)))
        .toList(growable: false);
  }

  static Map<String, int> _sanitizeGroupedCounts(dynamic countsRaw) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final source = countsRaw is Map ? countsRaw : const <String, dynamic>{};
    return {
      "reports": asInt(source["reports"]),
      "prescriptions": asInt(source["prescriptions"]),
      "bills": asInt(source["bills"]),
      "insurance": asInt(source["insurance"]),
    };
  }

  static Map<String, dynamic> _buildGroupedFromDocs(List<Document> docs) {
    final counts = {
      "reports": 0,
      "prescriptions": 0,
      "bills": 0,
      "insurance": 0,
    };
    for (final doc in docs) {
      switch (doc.normalizedType) {
        case "report":
          counts["reports"] = (counts["reports"] ?? 0) + 1;
          break;
        case "prescription":
          counts["prescriptions"] = (counts["prescriptions"] ?? 0) + 1;
          break;
        case "bill":
          counts["bills"] = (counts["bills"] ?? 0) + 1;
          break;
        case "insurance":
          counts["insurance"] = (counts["insurance"] ?? 0) + 1;
          break;
      }
    }
    return {
      "counts": counts,
      "source": "cache",
      "generatedFrom": "documents",
      "generatedAt": DateTime.now().toIso8601String(),
    };
  }

  static Future<void> _cacheDocuments(
    String userId,
    List<Document> docs,
  ) async {
    final normalizedUserId = _normalizeUserCacheId(userId);
    if (normalizedUserId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        "cachedAt": DateTime.now().toIso8601String(),
        "documents": docs.map((doc) => doc.toJson()).toList(growable: false),
      };
      await prefs.setString(
          _docsCacheKey(normalizedUserId), jsonEncode(payload));
      await prefs.setString(
        _groupedDocsCacheKey(normalizedUserId),
        jsonEncode(_buildGroupedFromDocs(docs)),
      );
    } catch (error) {
      _debugLog("cache documents failed: $error");
    }
  }

  static Future<void> _cacheGroupedDocs(
    String userId,
    Map<String, dynamic> grouped,
  ) async {
    final normalizedUserId = _normalizeUserCacheId(userId);
    if (normalizedUserId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        "cachedAt": DateTime.now().toIso8601String(),
        "counts": _sanitizeGroupedCounts(grouped["counts"]),
      };
      await prefs.setString(
        _groupedDocsCacheKey(normalizedUserId),
        jsonEncode(payload),
      );
    } catch (error) {
      _debugLog("cache grouped docs failed: $error");
    }
  }

  static Future<List<Document>> getCachedMyDocs(String userId) async {
    final normalizedUserId = _normalizeUserCacheId(userId);
    if (normalizedUserId.isEmpty) return const <Document>[];

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_docsCacheKey(normalizedUserId));
      if (raw == null || raw.trim().isEmpty) return const <Document>[];
      final parsed = jsonDecode(raw);
      if (parsed is Map) {
        return _documentsFromDynamicList(parsed["documents"]);
      }
    } catch (error) {
      _debugLog("read cached docs failed: $error");
    }
    return const <Document>[];
  }

  static Future<Map<String, dynamic>?> getCachedGroupedDocs(
      String userId) async {
    final normalizedUserId = _normalizeUserCacheId(userId);
    if (normalizedUserId.isEmpty) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_groupedDocsCacheKey(normalizedUserId));
      if (raw != null && raw.trim().isNotEmpty) {
        final parsed = jsonDecode(raw);
        if (parsed is Map) {
          return {
            "counts": _sanitizeGroupedCounts(parsed["counts"]),
            "source": "cache",
          };
        }
      }

      final cachedDocs = await getCachedMyDocs(normalizedUserId);
      if (cachedDocs.isEmpty) return null;
      return _buildGroupedFromDocs(cachedDocs);
    } catch (error) {
      _debugLog("read cached grouped docs failed: $error");
      return null;
    }
  }

  static Future<List<Document>> fetchMyDocs(String userId) async {
    final normalizedUserId = _normalizeUserCacheId(userId);
    if (normalizedUserId.isEmpty) return const <Document>[];

    try {
      Future<http.Response> fetch() async {
        final headers = await _authHeaders();
        return http
            .get(
              Uri.parse("$filesUrl/user/$normalizedUserId"),
              headers: headers,
            )
            .timeout(_documentsRequestTimeout);
      }

      var res = await fetch();
      if (res.statusCode == 401 || res.statusCode == 403) {
        final refreshed = await _refreshAccessTokenIfPossible();
        if (refreshed) {
          res = await fetch();
        }
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final docs = _documentsFromDynamicList(data["documents"]);
        await _cacheDocuments(normalizedUserId, docs);
        return docs;
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        final data = _decodeJsonMap(res.body);
        _emitSessionInvalid(
          (data['message'] ?? _defaultSessionExpiredMessage).toString(),
        );
      }
      _debugLog("Fetch docs failed (${res.statusCode}): ${res.body}");
    } catch (e) {
      _debugLog("Fetch docs error: $e");
    }

    final cached = await getCachedMyDocs(normalizedUserId);
    return cached;
  }

  static Future<Map<String, dynamic>?> fetchGroupedDocs(String userId) async {
    final normalizedUserId = _normalizeUserCacheId(userId);
    if (normalizedUserId.isEmpty) return null;

    try {
      Future<http.Response> fetch() async {
        final headers = await _authHeaders();
        return http
            .get(
              Uri.parse("$filesUrl/user/$normalizedUserId/grouped"),
              headers: headers,
            )
            .timeout(_documentsRequestTimeout);
      }

      var res = await fetch();
      if (res.statusCode == 401 || res.statusCode == 403) {
        final refreshed = await _refreshAccessTokenIfPossible();
        if (refreshed) {
          res = await fetch();
        }
      }

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          final normalized = {
            ...Map<String, dynamic>.from(decoded),
            "counts": _sanitizeGroupedCounts(decoded["counts"]),
          };
          await _cacheGroupedDocs(normalizedUserId, normalized);
          return normalized;
        }
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        final data = _decodeJsonMap(res.body);
        _emitSessionInvalid(
          (data['message'] ?? _defaultSessionExpiredMessage).toString(),
        );
      } else {
        _debugLog("Grouped fetch failed (${res.statusCode}): ${res.body}");
      }
    } catch (e) {
      _debugLog("Grouped fetch error: $e");
    }

    return getCachedGroupedDocs(normalizedUserId);
  }

  // ---------------- FETCH GROUPED DOCS BY EMAIL (for ProfilePageSettings) ----------------
  static Future<Map<String, dynamic>?> fetchGroupedDocsByEmail(
      String email) async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(Uri.parse("$filesUrl/grouped/$email"),
          headers: headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        print("Grouped fetch by email failed: ${res.body}");
      }
    } catch (e) {
      print("Grouped fetch by email error: $e");
    }
    return null;
  }

  // ---------------- DELETE ----------------
  static Future<Map<String, dynamic>?> updateDocument(
      String docId, Map<String, dynamic> updates) async {
    try {
      final headers = await _authHeaders();
      final res = await http.put(
        Uri.parse("$filesUrl/$docId"),
        headers: {...headers, "Content-Type": "application/json"},
        body: jsonEncode(updates),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data;
      } else {
        print("Update failed: ${res.body}");
        return null;
      }
    } catch (e) {
      print("Update error: $e");
      return null;
    }
  }

  static Future<bool> deleteDocument(String docId) async {
    try {
      final headers = await _authHeaders();
      final res =
          await http.delete(Uri.parse("$filesUrl/$docId"), headers: headers);

      if (res.statusCode == 200) {
        return true;
      } else {
        print("Delete failed: ${res.body}");
        return false;
      }
    } catch (e) {
      print("Delete error: $e");
      return false;
    }
  }

  // ---------------- QR ----------------
  static Future<String?> generateQrToken() async {
    try {
      final headers = await _authHeaders();
      // Try to hint backend to invalidate previous tokens when generating a new one.
      // These hints are optional and safely ignored if unsupported by backend.
      final uri = Uri.parse("$qrUrl/generate").replace(queryParameters: {
        // optional flags: backend may ignore them
        "invalidatePrevious": "true",
        "rotate": "true",
      });
      final res = await http.post(uri, headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['qrUrl'] ?? data['token'];
      } else {
        print("QR generation failed: ${res.body}");
      }
    } catch (e) {
      print("QR error: $e");
    }
    return null;
  }

  // Optionally ask backend to invalidate any existing QR tokens for the current user.
  // If the endpoint doesn't exist, this will no-op (handled via status code / exceptions).
  static Future<void> invalidatePreviousQrTokens() async {
    try {
      final headers = await _authHeaders();
      final candidates = <Uri>[
        Uri.parse("$qrUrl/invalidate"),
        Uri.parse("$qrUrl/expire-all"),
        Uri.parse("$qrUrl/rotate"),
      ];
      for (final uri in candidates) {
        try {
          final res = await http.post(uri, headers: headers);
          if (res.statusCode == 200) {
            // success on any one endpoint; stop trying others
            return;
          }
        } catch (_) {
          // ignore unsupported endpoints
        }
      }
    } catch (e) {
      // Silently ignore; feature is optional
      print("invalidatePreviousQrTokens error: $e");
    }
  }

  // ---------------- PROFILE MANAGEMENT ----------------
  static Future<List<Map<String, dynamic>>> getLinkedProfiles() async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(
        Uri.parse("${baseUrl}/profiles"),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(
            data['data']['linkedProfiles'] ?? []);
      } else {
        print("Get profiles failed: ${res.body}");
      }
    } catch (e) {
      print("Get profiles error: $e");
    }
    return [];
  }

  static Future<Map<String, dynamic>?> addSelfProfile(
      String email, String password) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse("${baseUrl}/profiles/add-self"),
        headers: {...headers, "Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data;
      } else {
        print("Add self profile failed: ${res.body}");
        final errorData = jsonDecode(res.body);
        throw Exception(errorData['message'] ?? 'Failed to add profile');
      }
    } catch (e) {
      print("Add self profile error: $e");
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> addOtherProfile({
    required String name,
    required String email,
    required String mobile,
    required String password,
  }) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse("${baseUrl}/profiles/add-other"),
        headers: {...headers, "Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "email": email,
          "mobile": mobile,
          "password": password,
        }),
      );
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return data;
      } else {
        print("Add other profile failed: ${res.body}");
        final errorData = jsonDecode(res.body);
        throw Exception(errorData['message'] ?? 'Failed to create profile');
      }
    } catch (e) {
      print("Add other profile error: $e");
      rethrow;
    }
  }

  // ---------------- USER PROFILE (PUBLIC/SELF) ----------------
  static Future<Map<String, dynamic>?> fetchUserPublicProfile(
      String userId) async {
    try {
      final token = await _getToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final res = await http.get(
        Uri.parse("${baseUrl}/users/$userId"),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // Common response shapes: { success, data: { user: {...} } }
        final user = data['data']?['user'] ?? data['user'];
        if (user is Map<String, dynamic>) {
          return user;
        }
      } else {
        print("Fetch user profile failed: ${res.body}");
      }
    } catch (e) {
      print("Fetch user profile error: $e");
    }
    return null;
  }

  // ---------------- SOS ----------------
  static Future<Map<String, dynamic>?> createSos({
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    String? notes,
    String? allergies,
    String? name,
    String? mobile,
    String? age,
    String? locationText,
    String? profileId,
  }) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse(sosUrl),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          if (accuracyMeters != null && accuracyMeters.isFinite)
            'accuracyMeters': accuracyMeters,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          if (allergies != null && allergies.trim().isNotEmpty)
            'allergies': allergies.trim(),
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
          if (mobile != null && mobile.trim().isNotEmpty)
            'mobile': mobile.trim(),
          if (age != null && age.trim().isNotEmpty) 'age': age.trim(),
          if (locationText != null && locationText.trim().isNotEmpty)
            'locationText': locationText.trim(),
          if (profileId != null && profileId.trim().isNotEmpty)
            'profileId': profileId.trim(),
        }),
      );
      if (res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      print('createSos failed: ${res.statusCode} ${res.body}');
      return null;
    } catch (e) {
      print('createSos error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> createSosEvent(
    Map<String, dynamic> event,
  ) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse("$sosUrl/events"),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode(event),
      );
      final decoded = _decodeJsonMap(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return decoded;
      }
      print('createSosEvent failed: ${res.statusCode} ${res.body}');
      return null;
    } catch (e) {
      print('createSosEvent error: $e');
      return null;
    }
  }

  // ---------------- GOOGLE PROFILE MANAGEMENT ----------------

  /// Link an existing Google account to current user's profile
  static Future<Map<String, dynamic>?> linkGoogleProfile() async {
    try {
      // Get Google authentication data
      final googleData = await GoogleAuthHelper.signInWithGoogle();
      if (googleData == null) {
        print("Google sign-in canceled");
        return null;
      }

      // Send to backend with current auth token
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse("${baseUrl}/profiles/link-google"),
        headers: {...headers, "Content-Type": "application/json"},
        body: jsonEncode({"idToken": googleData['idToken']}),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return data;
      } else {
        print("Link Google profile failed: ${res.body}");
        final errorData = jsonDecode(res.body);
        throw Exception(
            errorData['message'] ?? 'Failed to link Google profile');
      }
    } catch (e) {
      print("Link Google profile error: $e");
      rethrow;
    }
  }

  /// Create a new Google profile under current user
  static Future<Map<String, dynamic>?> createGoogleProfile() async {
    try {
      // Get Google authentication data
      final googleData = await GoogleAuthHelper.signInWithGoogle();
      if (googleData == null) {
        print("Google sign-in canceled");
        return null;
      }

      // Create new profile via backend
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse("${baseUrl}/profiles/create-google"),
        headers: {...headers, "Content-Type": "application/json"},
        body: jsonEncode({"idToken": googleData['idToken']}),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return data;
      } else {
        print("Create Google profile failed: ${res.body}");
        final errorData = jsonDecode(res.body);
        throw Exception(
            errorData['message'] ?? 'Failed to create Google profile');
      }
    } catch (e) {
      print("Create Google profile error: $e");
      rethrow;
    }
  }

  /// Switch to a profile (Google or email/password)
  /// For Google profiles: uses idToken (no password needed)
  /// For email profiles: uses password
  static Future<Map<String, dynamic>?> switchProfile(
      Map<String, dynamic> profile,
      {String? password}) async {
    try {
      final profileId =
          profile['_id']?.toString() ?? profile['id']?.toString() ?? '';
      final loginType = profile['loginType']?.toString() ??
          (profile['googleId'] != null ? 'google' : 'email');

      final headers = await _authHeaders();
      Map<String, dynamic> requestBody = {};

      // Handle Google profiles
      if (loginType == 'google') {
        // Get Google authentication
        final googleData = await GoogleAuthHelper.signInWithGoogle();
        if (googleData == null) {
          print("Google sign-in canceled");
          return null;
        }

        // Verify email matches
        if (googleData['email'] != profile['email']) {
          throw Exception(
              'Selected Google account doesn\'t match profile email.\n'
              'Expected: ${profile['email']}\n'
              'Selected: ${googleData['email']}');
        }

        requestBody['idToken'] = googleData['idToken'];
      } else {
        // Handle email/password profiles
        if (password == null || password.isEmpty) {
          throw Exception('Password is required for email/password profiles');
        }
        requestBody['password'] = password;
      }

      final res = await http.post(
        Uri.parse("${baseUrl}/profiles/switch/$profileId"),
        headers: {...headers, "Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final dataMap = data is Map
            ? data.map((key, value) => MapEntry(key.toString(), value))
            : <String, dynamic>{};
        final payload = dataMap['data'] is Map
            ? (dataMap['data'] as Map)
                .map((key, value) => MapEntry(key.toString(), value))
            : <String, dynamic>{};
        final user = payload['user'] is Map
            ? (payload['user'] as Map)
                .map((key, value) => MapEntry(key.toString(), value))
            : <String, dynamic>{};

        if (payload['token'] != null) {
          await _persistAuthSessionPayload(payload);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            "activeProfileId",
            user['id']?.toString() ?? user['_id']?.toString() ?? "",
          );
        }

        return data;
      } else {
        print("Switch profile failed: ${res.body}");
        final errorData = jsonDecode(res.body);
        throw Exception(errorData['message'] ?? 'Failed to switch profile');
      }
    } catch (e) {
      print("Switch profile error: $e");
      rethrow;
    }
  }

  static Future<bool> removeLinkedProfile(String profileId) async {
    try {
      final headers = await _authHeaders();
      final res = await http.delete(
        Uri.parse("${baseUrl}/profiles/remove/$profileId"),
        headers: headers,
      );
      if (res.statusCode == 200) {
        return true;
      } else {
        print("Remove profile failed: ${res.body}");
        return false;
      }
    } catch (e) {
      print("Remove profile error: $e");
      return false;
    }
  }

  // ---------------- APPOINTMENTS ----------------
  static Future<List<dynamic>> fetchUpcomingAppointments() async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(
        Uri.parse("$patientAppointmentsUrl/upcoming"),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['appointments'] != null) {
          return List<dynamic>.from(data['appointments']);
        }
      }
    } catch (e) {
      print("fetchUpcomingAppointments error: $e");
    }
    return [];
  }

  static Future<List<dynamic>> fetchPastAppointments({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _pastAppointmentsCache != null &&
        _pastAppointmentsCache!.isValid) {
      return _pastAppointmentsCache!.value;
    }

    try {
      final headers = await _authHeaders();
      final res = await http
          .get(
            Uri.parse("$patientAppointmentsUrl/past"),
            headers: headers,
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['appointments'] != null) {
          final appointments = List<dynamic>.from(data['appointments']);
          _pastAppointmentsCache = _TimedCacheEntry(
            value: appointments,
            expiresAt: DateTime.now().add(_appointmentsCacheTtl),
          );
          return appointments;
        }
      }
    } catch (e) {
      print("fetchPastAppointments error: $e");
    }
    if (_pastAppointmentsCache != null) {
      return _pastAppointmentsCache!.value;
    }
    return [];
  }

  static Future<Map<String, dynamic>?> fetchAppointmentDetail(String id) async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(
        Uri.parse("$patientAppointmentsUrl/$id"),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['appointment'] != null) {
          return data['appointment'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      print("fetchAppointmentDetail error: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> requestReschedule(
      String id, Map<String, dynamic> body) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse("$patientAppointmentsUrl/$id/reschedule-request"),
        headers: {...headers, "Content-Type": "application/json"},
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print("requestReschedule error: $e");
    }
    return null;
  }

  static Future<bool> cancelAppointment(String id) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse("$patientAppointmentsUrl/$id/cancel"),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] == true;
      }
    } catch (e) {
      print("cancelAppointment error: $e");
    }
    return false;
  }

  static String _formatDateOnly(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  static Future<Map<String, dynamic>> requestAppointment({
    required String doctorId,
    required DateTime appointmentDate,
    required String appointmentTime,
    required String reason,
    int duration = 30,
    String appointmentType = 'consultation',
    String mode = 'in-person',
    String notes = '',
    String? patientId,
    String? patientName,
    String? patientEmail,
    String? patientPhone,
  }) async {
    final normalizedDoctorId = doctorId.trim();
    final normalizedTime = appointmentTime.trim();
    final normalizedReason = reason.trim();
    final normalizedType = appointmentType.trim().isEmpty
        ? 'consultation'
        : appointmentType.trim();
    final normalizedMode =
        mode.trim().toLowerCase() == 'online' ? 'online' : 'in-person';

    if (normalizedDoctorId.isEmpty ||
        normalizedTime.isEmpty ||
        normalizedReason.isEmpty) {
      return {
        "success": false,
        "message": "Doctor, date, time, and reason are required.",
      };
    }

    final payload = <String, dynamic>{
      "doctorId": normalizedDoctorId,
      "appointmentDate": _formatDateOnly(appointmentDate),
      "appointmentTime": normalizedTime,
      "duration": duration.clamp(15, 180),
      "reason": normalizedReason,
      "appointmentType": normalizedType,
      "mode": normalizedMode,
    };

    final normalizedNotes = notes.trim();
    if (normalizedNotes.isNotEmpty) payload["notes"] = normalizedNotes;
    if (patientId != null && patientId.trim().isNotEmpty) {
      payload["patientId"] = patientId.trim();
    }
    if (patientName != null && patientName.trim().isNotEmpty) {
      payload["patientName"] = patientName.trim();
    }
    if (patientEmail != null && patientEmail.trim().isNotEmpty) {
      payload["patientEmail"] = patientEmail.trim();
    }
    if (patientPhone != null && patientPhone.trim().isNotEmpty) {
      payload["patientPhone"] = patientPhone.trim();
    }

    try {
      final response = await _sendAuthorizedRequestWithRetry(
        (headers) => http.post(
          Uri.parse("$patientAppointmentsUrl/request"),
          headers: {...headers, "Content-Type": "application/json"},
          body: jsonEncode(payload),
        ),
      );
      final data = _decodeJsonMap(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['success'] == true) {
        return {
          "success": true,
          "message":
              (data['message'] ?? "Appointment request submitted successfully.")
                  .toString(),
          "appointment": data['appointment'],
        };
      }
      return {
        "success": false,
        "message":
            (data['message'] ?? "Failed to request appointment.").toString(),
      };
    } catch (_) {
      return {
        "success": false,
        "message": "Failed to request appointment.",
      };
    }
  }

  static Future<Map<String, dynamic>> respondToSessionExtensionRequest({
    required String sessionId,
    required bool accept,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return {
        "success": false,
        "message": "Invalid session id.",
      };
    }

    final status = accept ? 'accepted' : 'declined';

    try {
      final response = await _sendAuthorizedRequestWithRetry(
        (headers) => http.post(
          Uri.parse("$baseUrl/sessions/extend/$normalizedSessionId/respond"),
          headers: {...headers, "Content-Type": "application/json"},
          body: jsonEncode({"status": status}),
        ),
      );
      final data = _decodeJsonMap(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        return {
          "success": true,
          "message": (data['message'] ??
                  (accept
                      ? "Session extension approved."
                      : "Session extension declined."))
              .toString(),
          "data": data['data'],
        };
      }
      return {
        "success": false,
        "message":
            (data['message'] ?? "Failed to respond to extension.").toString(),
      };
    } catch (_) {
      return {
        "success": false,
        "message": "Failed to respond to extension.",
      };
    }
  }

  static Future<Map<String, dynamic>?> getAppointmentAISummary(
      String id) async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(
        Uri.parse("$patientAppointmentsUrl/$id/ai-summary"),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          return data as Map<String, dynamic>;
        }
      }
    } catch (e) {
      print("getAppointmentAISummary error: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> generateAppointmentAISummary(
      String appointmentId) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse("$aiUrl/appointment-summary"),
        headers: {...headers, "Content-Type": "application/json"},
        body: jsonEncode({"appointmentId": appointmentId}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          return data as Map<String, dynamic>;
        }
      }
    } catch (e) {
      print("generateAppointmentAISummary error: $e");
    }
    return null;
  }

  static Future<List<dynamic>> fetchNotificationHistory() async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(
        Uri.parse("$baseUrl/notifications"),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['data']?['notifications'] ?? data['notifications'];
        if (list != null) return List<dynamic>.from(list);
      }
    } catch (e) {
      print("fetchNotificationHistory error: $e");
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchChatThreads() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse("$baseUrl/sessions/chat/threads"),
        headers: headers,
      );
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      if (data["success"] != true || data["threads"] is! List) return [];
      return (data["threads"] as List).whereType<Map>().map((entry) {
        final mapped = entry.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        return {
          ...mapped,
          "counterpartRole": "doctor",
          "counterpartAvatar":
              resolveMediaUrl(mapped["counterpartAvatar"]?.toString()) ?? "",
        };
      }).toList(growable: false);
    } catch (e) {
      print("fetchChatThreads error: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchChatMessages(
    String counterpartId, {
    int limit = 300,
  }) async {
    try {
      final headers = await _authHeaders();
      final normalizedId = counterpartId.trim();
      if (normalizedId.isEmpty) return [];
      final safeLimit = limit.clamp(1, 500);
      final uri = Uri.parse(
          "$baseUrl/sessions/chat/messages/$normalizedId?limit=$safeLimit");
      final response = await http.get(uri, headers: headers);
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      if (data["success"] != true || data["messages"] is! List) return [];
      return (data["messages"] as List)
          .whereType<Map>()
          .map((entry) => entry.map(
                (key, value) => MapEntry(key.toString(), value),
              ))
          .toList(growable: false);
    } catch (e) {
      print("fetchChatMessages error: $e");
      return [];
    }
  }

  static Future<Map<String, dynamic>?> sendDirectMessage({
    required String counterpartId,
    required String message,
    String? sessionId,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse("$baseUrl/sessions/chat/send"),
        headers: {
          ...headers,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "counterpartId": counterpartId.trim(),
          "message": message.trim(),
          if (sessionId != null && sessionId.trim().isNotEmpty)
            "sessionId": sessionId.trim(),
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data as Map<String, dynamic>;
      }
      return {
        "success": false,
        "message": data["message"]?.toString() ?? "Failed to send message",
      };
    } catch (e) {
      print("sendDirectMessage error: $e");
      return {
        "success": false,
        "message": "Network error",
      };
    }
  }

  static Future<Map<String, dynamic>?> sendMessageToDoctor({
    required String doctorId,
    required String doctorName,
    required String message,
    String? sessionId,
  }) async {
    return sendDirectMessage(
      counterpartId: doctorId,
      message: message,
      sessionId: sessionId,
    );
  }

  // ---------------- PUBLIC CONFIG ----------------
  static Future<List<Map<String, dynamic>>> fetchAdvertisements({
    String? placement,
    bool forceRefresh = false,
  }) async {
    final normalizedPlacement = (placement ?? "").trim().toUpperCase();
    final geoScope = await _resolvePublicGeoScope(forceRefresh: forceRefresh);
    final cacheKey =
        "${normalizedPlacement.isEmpty ? "ALL" : normalizedPlacement}|${geoScope.cacheKey}";

    if (!forceRefresh) {
      final cached = _adsCache[cacheKey];
      if (cached != null && cached.isValid) {
        return cached.value;
      }
    }

    try {
      final query = <String, String>{};
      if (normalizedPlacement.isNotEmpty) {
        query["placement"] = normalizedPlacement;
      }
      query.addAll(geoScope.toQueryParameters());

      final uri = Uri.parse("$publicUrl/ads").replace(
        queryParameters: query.isEmpty ? null : query,
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      final adsRaw = data["ads"];
      if (adsRaw is! List) return [];

      final ads = adsRaw
          .whereType<Map>()
          .map((item) => item.map(
                (key, value) => MapEntry(key.toString(), value),
              ))
          .toList(growable: false);

      _adsCache[cacheKey] = _TimedCacheEntry(
        value: ads,
        expiresAt: DateTime.now().add(_publicCacheTtl),
      );
      return ads;
    } catch (e) {
      print("fetchAdvertisements error: $e");
      return [];
    }
  }

  static Future<String?> fetchTrackedAdvertisementUrl({
    required String adId,
    required String placement,
    String platform = "app",
    String sourceApp = "healthvault_flutter",
  }) async {
    try {
      final normalizedAdId = adId.trim();
      if (normalizedAdId.isEmpty) return null;

      final prefs = await SharedPreferences.getInstance();
      final userId = (prefs.getString("userId") ?? "").trim();

      String userType = "anonymous";
      final rawUserData = prefs.getString("userData");
      if (rawUserData != null && rawUserData.isNotEmpty) {
        try {
          final parsed = jsonDecode(rawUserData);
          if (parsed is Map<String, dynamic>) {
            userType = (parsed["role"]?.toString().trim().toLowerCase() ?? "");
            if (userType.isEmpty) {
              userType = "patient";
            }
          }
        } catch (_) {
          // ignore malformed user data
        }
      }

      final response = await http
          .post(
            Uri.parse("$publicUrl/ads/$normalizedAdId/click"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "platform": platform,
              "surface": placement.trim().toUpperCase(),
              "userId": userId,
              "userType": userType,
              "sourceApp": sourceApp,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final trackedUrl = data["trackedUrl"]?.toString().trim();
      if (trackedUrl == null || trackedUrl.isEmpty) return null;
      return trackedUrl;
    } catch (e) {
      print("fetchTrackedAdvertisementUrl error: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchUiConfig({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _uiConfigCache != null && _uiConfigCache!.isValid) {
      return _uiConfigCache!.value;
    }

    try {
      final response = await http
          .get(Uri.parse("$publicUrl/ui-config"))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final config = data["config"];
      if (config is! Map) return null;

      final map = config.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      _uiConfigCache = _TimedCacheEntry(
        value: map,
        expiresAt: DateTime.now().add(_publicCacheTtl),
      );
      return map;
    } catch (e) {
      print("fetchUiConfig error: $e");
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPublicProducts({
    String? category,
  }) async {
    try {
      final normalizedCategory = (category ?? "").trim();
      final geoScope = await _resolvePublicGeoScope();
      final query = <String, String>{};
      if (normalizedCategory.isNotEmpty) {
        query["category"] = normalizedCategory;
      }
      query.addAll(geoScope.toQueryParameters());
      final uri = Uri.parse("$publicUrl/products").replace(
        queryParameters: query.isEmpty ? null : query,
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      final productsRaw = data["products"];
      if (productsRaw is! List) return [];
      return productsRaw
          .whereType<Map>()
          .map((item) => item.map(
                (key, value) => MapEntry(key.toString(), value),
              ))
          .toList(growable: false);
    } catch (e) {
      print("fetchPublicProducts error: $e");
      return [];
    }
  }

  // ---------------- STORE ----------------
  static Future<Map<String, dynamic>> fetchStoreProducts({
    String search = "",
    String category = "",
    double? minPrice,
    double? maxPrice,
    double? minRating,
    String sort = "newest",
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final query = <String, String>{
        "page": page.clamp(1, 100000).toString(),
        "limit": limit.clamp(1, 60).toString(),
      };
      final normalizedSearch = search.trim();
      final normalizedCategory = category.trim();
      if (normalizedSearch.isNotEmpty) query["search"] = normalizedSearch;
      if (normalizedCategory.isNotEmpty) query["category"] = normalizedCategory;
      if (minPrice != null && minPrice >= 0) {
        query["minPrice"] = minPrice.toStringAsFixed(2);
      }
      if (maxPrice != null && maxPrice >= 0) {
        query["maxPrice"] = maxPrice.toStringAsFixed(2);
      }
      if (minRating != null && minRating >= 0) {
        query["minRating"] = minRating.toStringAsFixed(1);
      }
      if (sort.trim().isNotEmpty) {
        query["sort"] = sort.trim().toLowerCase();
      }

      final uri = Uri.parse("$baseUrl/products").replace(
        queryParameters: query,
      );
      final response = await _sendAuthorizedRequestWithRetry(
        (headers) => http.get(uri, headers: headers),
      );
      final data = _decodeJsonMap(response.body);
      if (response.statusCode != 200 || data['success'] == false) {
        return {
          "success": false,
          "message": (data['message'] ?? "Failed to fetch products").toString(),
          "products": <Map<String, dynamic>>[],
          "pagination": const <String, dynamic>{},
        };
      }

      final productsRaw = data['products'];
      final products = productsRaw is List
          ? productsRaw
              .whereType<Map>()
              .map(
                (item) => item.map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              )
              .toList(growable: false)
          : <Map<String, dynamic>>[];

      final pagination = data['pagination'] is Map
          ? (data['pagination'] as Map)
              .map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};

      return {
        "success": true,
        "products": products,
        "pagination": pagination,
      };
    } catch (e) {
      return {
        "success": false,
        "message": "Failed to fetch products",
        "products": <Map<String, dynamic>>[],
        "pagination": const <String, dynamic>{},
      };
    }
  }

  static Future<Map<String, dynamic>> fetchStoreCart() async {
    try {
      final response = await _sendAuthorizedRequestWithRetry(
        (headers) => http.get(Uri.parse("$baseUrl/cart"), headers: headers),
      );
      final data = _decodeJsonMap(response.body);
      if (response.statusCode != 200 || data['success'] == false) {
        return {
          "success": false,
          "message": (data['message'] ?? "Failed to fetch cart").toString(),
          "cart": {
            "items": <Map<String, dynamic>>[],
            "totals": {"itemCount": 0, "subtotal": 0},
          },
        };
      }
      final cart = data['cart'] is Map
          ? (data['cart'] as Map)
              .map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      return {"success": true, "cart": cart};
    } catch (e) {
      return {
        "success": false,
        "message": "Failed to fetch cart",
        "cart": {
          "items": <Map<String, dynamic>>[],
          "totals": {"itemCount": 0, "subtotal": 0},
        },
      };
    }
  }

  static Future<Map<String, dynamic>> addStoreCartItem({
    required String productId,
    int quantity = 1,
  }) async {
    try {
      final response = await _sendAuthorizedRequestWithRetry(
        (headers) => http.post(
          Uri.parse("$baseUrl/cart/items"),
          headers: {...headers, "Content-Type": "application/json"},
          body: jsonEncode({
            "productId": productId.trim(),
            "quantity": quantity.clamp(1, 20),
          }),
        ),
      );
      final data = _decodeJsonMap(response.body);
      if ((response.statusCode != 200 && response.statusCode != 201) ||
          data['success'] == false) {
        return {
          "success": false,
          "message": (data['message'] ?? "Failed to update cart").toString(),
          "cart": data['cart'],
        };
      }
      return {"success": true, "cart": data['cart']};
    } catch (e) {
      return {
        "success": false,
        "message": "Failed to update cart",
      };
    }
  }

  static Future<Map<String, dynamic>> updateStoreCartItem({
    required String itemId,
    required int quantity,
  }) async {
    try {
      final response = await _sendAuthorizedRequestWithRetry(
        (headers) => http.patch(
          Uri.parse("$baseUrl/cart/items/${itemId.trim()}"),
          headers: {...headers, "Content-Type": "application/json"},
          body: jsonEncode({
            "quantity": quantity.clamp(0, 20),
          }),
        ),
      );
      final data = _decodeJsonMap(response.body);
      if (response.statusCode != 200 || data['success'] == false) {
        return {
          "success": false,
          "message": (data['message'] ?? "Failed to update cart").toString(),
          "cart": data['cart'],
        };
      }
      return {"success": true, "cart": data['cart']};
    } catch (e) {
      return {
        "success": false,
        "message": "Failed to update cart",
      };
    }
  }

  static Future<Map<String, dynamic>> removeStoreCartItem({
    required String itemId,
  }) async {
    try {
      final response = await _sendAuthorizedRequestWithRetry(
        (headers) => http.delete(
          Uri.parse("$baseUrl/cart/items/${itemId.trim()}"),
          headers: headers,
        ),
      );
      final data = _decodeJsonMap(response.body);
      if (response.statusCode != 200 || data['success'] == false) {
        return {
          "success": false,
          "message": (data['message'] ?? "Failed to remove item").toString(),
          "cart": data['cart'],
        };
      }
      return {"success": true, "cart": data['cart']};
    } catch (e) {
      return {
        "success": false,
        "message": "Failed to remove item",
      };
    }
  }

  static Future<Map<String, dynamic>> createStoreOrder({
    required Map<String, dynamic> delivery,
  }) async {
    try {
      final response = await _sendAuthorizedRequestWithRetry(
        (headers) => http.post(
          Uri.parse("$baseUrl/orders"),
          headers: {...headers, "Content-Type": "application/json"},
          body: jsonEncode({"delivery": delivery}),
        ),
      );
      final data = _decodeJsonMap(response.body);
      if (response.statusCode != 201 || data['success'] == false) {
        return {
          "success": false,
          "message": (data['message'] ?? "Failed to place order").toString(),
          "order": data['order'],
        };
      }
      return {"success": true, "order": data['order']};
    } catch (e) {
      return {
        "success": false,
        "message": "Failed to place order",
      };
    }
  }

  static Future<Map<String, dynamic>> fetchStoreOrders({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/orders").replace(
        queryParameters: {
          "page": page.clamp(1, 100000).toString(),
          "limit": limit.clamp(1, 60).toString(),
        },
      );
      final response = await _sendAuthorizedRequestWithRetry(
        (headers) => http.get(uri, headers: headers),
      );
      final data = _decodeJsonMap(response.body);
      if (response.statusCode != 200 || data['success'] == false) {
        return {
          "success": false,
          "message": (data['message'] ?? "Failed to fetch orders").toString(),
          "orders": const <Map<String, dynamic>>[],
          "pagination": const <String, dynamic>{},
        };
      }
      final ordersRaw = data['orders'];
      final orders = ordersRaw is List
          ? ordersRaw
              .whereType<Map>()
              .map(
                (item) => item.map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              )
              .toList(growable: false)
          : <Map<String, dynamic>>[];
      final pagination = data['pagination'] is Map
          ? (data['pagination'] as Map)
              .map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      return {"success": true, "orders": orders, "pagination": pagination};
    } catch (e) {
      return {
        "success": false,
        "message": "Failed to fetch orders",
        "orders": const <Map<String, dynamic>>[],
        "pagination": const <String, dynamic>{},
      };
    }
  }

  // ---------------- NEARBY ----------------
  static bool isNearbyCacheStale(Map<String, dynamic>? cachedPayload) {
    if (cachedPayload == null) return true;
    final lastUpdatedRaw =
        (cachedPayload['lastUpdatedAt'] ?? cachedPayload['cachedAt'] ?? '')
            .toString()
            .trim();
    if (lastUpdatedRaw.isEmpty) return true;
    final parsed = DateTime.tryParse(lastUpdatedRaw);
    if (parsed == null) return true;
    final age = DateTime.now().difference(parsed.toLocal());
    return age > _nearbyFreshnessTtl;
  }

  static Future<Map<String, dynamic>?> getCachedNearbyServices() async {
    return OfflineStorageService.instance.getCachedNearbyServices();
  }

  static Future<Map<String, dynamic>> fetchNearbyServices({
    required double latitude,
    required double longitude,
    int radius = 5000,
    double? radiusKm,
    List<String> types = const [
      "hospital",
      "clinic",
      "ambulance",
      "doctor",
      "pharmacy",
      "diagnostic_lab",
    ],
  }) async {
    final normalizedRadius = radius.clamp(500, 50000);
    final normalizedRadiusKm =
        (radiusKm ?? (normalizedRadius / 1000)).clamp(0.5, 50).toDouble();
    final normalizedTypes = types
        .map((entry) => entry.trim().toLowerCase())
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList(growable: false);

    try {
      final uri = Uri.parse("$baseUrl/nearby/services").replace(
        queryParameters: {
          "lat": latitude.toStringAsFixed(6),
          "lng": longitude.toStringAsFixed(6),
          "radiusKm": normalizedRadiusKm.toStringAsFixed(2),
          "type": normalizedTypes.join(","),
        },
      );

      final response = await _sendAuthorizedRequestWithRetry(
        (headers) => http.get(uri, headers: headers),
      );
      final data = _decodeJsonMap(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final payload = {
          "services": data['services'],
          "criticalServices": data['criticalServices'],
          "lastUpdatedAt": (data['lastUpdatedAt'] ??
                  DateTime.now().toUtc().toIso8601String())
              .toString(),
          "cachedAt": DateTime.now().toUtc().toIso8601String(),
          "radiusKm": normalizedRadiusKm,
          "types": normalizedTypes,
        };
        await OfflineStorageService.instance.cacheNearbyServices(payload);

        return {
          "success": true,
          "services": data['services'] ?? const <Map<String, dynamic>>[],
          "criticalServices":
              data['criticalServices'] ?? const <Map<String, dynamic>>[],
          "fallback": data['fallback'] ?? const <Map<String, dynamic>>[],
          "actionCards": data['actionCards'] ?? const <Map<String, dynamic>>[],
          "source": (data['source'] ?? '').toString(),
          "message": (data['message'] ?? '').toString(),
          "lastUpdatedAt": payload["lastUpdatedAt"],
          "isCached": false,
          "isStale": false,
        };
      }

      final cached = await getCachedNearbyServices();
      if (cached != null) {
        return {
          "success": true,
          "services": cached['services'] ?? const <Map<String, dynamic>>[],
          "criticalServices":
              cached['criticalServices'] ?? const <Map<String, dynamic>>[],
          "lastUpdatedAt": cached['lastUpdatedAt'] ?? cached['cachedAt'] ?? '',
          "isCached": true,
          "isStale": isNearbyCacheStale(cached),
          "message":
              (data['message'] ?? "Showing cached nearby services").toString(),
        };
      }

      return {
        "success": false,
        "code": (data['code'] ?? '').toString(),
        "message":
            (data['message'] ?? "Failed to fetch nearby services").toString(),
        "services": const <Map<String, dynamic>>[],
        "criticalServices":
            data['criticalServices'] ?? const <Map<String, dynamic>>[],
        "fallback": data['fallback'] ?? const <Map<String, dynamic>>[],
        "actionCards": data['actionCards'] ?? const <Map<String, dynamic>>[],
        "isCached": false,
        "isStale": true,
      };
    } catch (e) {
      final cached = await getCachedNearbyServices();
      if (cached != null) {
        return {
          "success": true,
          "services": cached['services'] ?? const <Map<String, dynamic>>[],
          "criticalServices":
              cached['criticalServices'] ?? const <Map<String, dynamic>>[],
          "lastUpdatedAt": cached['lastUpdatedAt'] ?? cached['cachedAt'] ?? '',
          "isCached": true,
          "isStale": isNearbyCacheStale(cached),
          "message": "Showing cached nearby services",
        };
      }
      return {
        "success": false,
        "message": "Failed to fetch nearby services",
        "services": const <Map<String, dynamic>>[],
        "criticalServices": const <Map<String, dynamic>>[],
        "isCached": false,
        "isStale": true,
      };
    }
  }

  // ---------------- AI ASSISTANT ----------------
  static Future<Map<String, dynamic>?> askAI(String prompt) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse("$aiUrl/ask"),
        headers: {...headers, "Content-Type": "application/json"},
        body: jsonEncode({"prompt": prompt}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data;
      } else {
        print("AI request failed: ${res.body}");
        final errorData = jsonDecode(res.body);
        return {
          "success": false,
          "message": errorData['message'] ?? 'AI request failed',
          "reply":
              "I'm sorry, I'm having trouble connecting right now. Please try again later."
        };
      }
    } catch (e) {
      print("AI request error: $e");
      return {
        "success": false,
        "message": "Network error",
        "reply":
            "I'm having trouble connecting to the AI service. Please check your internet connection and try again."
      };
    }
  }

  static Future<Map<String, dynamic>?> askKhojAI({
    required String message,
    String? reportId,
    String? reportType,
  }) async {
    try {
      final headers = await _authHeaders();
      final res = await http.post(
        Uri.parse("$khojUrl/assistant/chat"),
        headers: {...headers, "Content-Type": "application/json"},
        body: jsonEncode({
          "message": message,
          if (reportId != null && reportId.trim().isNotEmpty)
            "reportId": reportId.trim(),
          if (reportType != null && reportType.trim().isNotEmpty)
            "reportType": reportType.trim(),
        }),
      );

      final data = _decodeJsonMap(res.body);
      if (res.statusCode == 200) {
        return data;
      }
      return {
        "success": false,
        "message": data['message'] ?? 'KHOJ AI request failed',
        "reply":
            "KHOJ AI can only analyze lost/found person reports you are authorized to access."
      };
    } catch (e) {
      print("KHOJ AI error: $e");
      return {
        "success": false,
        "message": "Network error",
        "reply":
            "KHOJ AI is unavailable right now. Please check your connection and try again."
      };
    }
  }

  static Future<bool> checkAIStatus() async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(
        Uri.parse("$aiUrl/status"),
        headers: headers,
      );

      if (res.statusCode == 200) {
        return true;
      } else {
        print("AI status check failed: ${res.body}");
        return false;
      }
    } catch (e) {
      print("AI status check error: $e");
      return false;
    }
  }
}

class _PublicGeoScope {
  final String country;
  final String state;
  final String region;

  const _PublicGeoScope({
    this.country = "",
    this.state = "",
    this.region = "",
  });

  const _PublicGeoScope.empty()
      : country = "",
        state = "",
        region = "";

  bool get isEmpty => country.isEmpty && state.isEmpty && region.isEmpty;

  _PublicGeoScope withFallback(_PublicGeoScope fallback) {
    return _PublicGeoScope(
      country: country.isNotEmpty ? country : fallback.country,
      state: state.isNotEmpty ? state : fallback.state,
      region: region.isNotEmpty ? region : fallback.region,
    );
  }

  Map<String, String> toQueryParameters() {
    final query = <String, String>{};
    if (country.isNotEmpty) query["country"] = country;
    if (state.isNotEmpty) query["state"] = state;
    if (region.isNotEmpty) query["region"] = region;
    return query;
  }

  String get cacheKey =>
      "${country.isEmpty ? "*" : country}|${state.isEmpty ? "*" : state}|${region.isEmpty ? "*" : region}";
}

class _TimedCacheEntry<T> {
  final T value;
  final DateTime expiresAt;

  const _TimedCacheEntry({
    required this.value,
    required this.expiresAt,
  });

  bool get isValid => DateTime.now().isBefore(expiresAt);
}
