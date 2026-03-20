import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:hello/Notifications/fcm_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import 'Document_model.dart';
import 'package:dio/dio.dart';
import 'package:hello/helpers/google_auth_helper.dart';

class ApiService {
  static const String _defaultApiBaseUrl =
      "https://backend-medicalvault.onrender.com/api";
  static const String baseUrl =
      String.fromEnvironment("API_BASE_URL", defaultValue: _defaultApiBaseUrl);
  static const String authUrl = "$baseUrl/auth";
  static const String filesUrl = "$baseUrl/files";
  static const String qrUrl = "$baseUrl/qr";
  static const String aiUrl = "$baseUrl/ai";
  static const String sosUrl = "$baseUrl/sos";
  static const String lostFoundUrl = "$baseUrl/lost-found";
  static const String patientAppointmentsUrl = "$baseUrl/patient/appointments";
  static const String publicUrl = "$baseUrl/public";

  static const Duration _publicCacheTtl = Duration(minutes: 5);
  static const Duration _appointmentsCacheTtl = Duration(minutes: 3);
  static final Map<String, _TimedCacheEntry<List<Map<String, dynamic>>>>
      _adsCache = {};
  static _TimedCacheEntry<Map<String, dynamic>>? _uiConfigCache;
  static _TimedCacheEntry<List<dynamic>>? _pastAppointmentsCache;

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

  // ---------------- TOKEN ----------------
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  // ✅ Public method to get token for Dio requests
  static Future<String?> getToken() async {
    return _getToken();
  }

  // ---------------- PASSWORD FLOWS ----------------
  // ---------------- EMAIL VERIFICATION ----------------
  static Future<Map<String, dynamic>?> verifyEmailWithToken(
      String token) async {
    try {
      final res = await http.post(
        Uri.parse("$authUrl/verify?token=${Uri.encodeQueryComponent(token)}"),
        headers: {"Content-Type": "application/json"},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
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
        print("Forgot password failed: ${res.body}");
        return {"success": false, "message": "Failed to send reset email"};
      }
    } catch (e) {
      print("Forgot password error: $e");
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
      print("Reset password error: $e");
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
      print("Change password error: $e");
      return {"success": false, "message": "Network error"};
    }
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      HttpHeaders.authorizationHeader: 'Bearer ${token ?? ''}',
    };
  }

  // ---------------- LOGIN ----------------
  static Future<Map<String, dynamic>?> login(
      String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse("$authUrl/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['token'];
        final user = data['user'];

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("authToken", token);
          await prefs.setString("userId", user?['id']?.toString() ?? "");
          await prefs.setString("email", user?['email']?.toString() ?? "");
          await prefs.setString("name", user?['name']?.toString() ?? "Patient");
          // ✅ Also store userData for dashboard compatibility
          await prefs.setString("userData", jsonEncode(user));
          // Store emailVerified flag for convenience
          if (user != null && user['emailVerified'] != null) {
            await prefs.setBool('emailVerified', user['emailVerified'] == true);
          }

          // Register FCM token after successful login
          await FCMService().registerToken();
        }

        return data;
      } else {
        print("Login failed: ${res.body}");
        return null;
      }
    } catch (e) {
      print("Login error: $e");
      return null;
    }
  }

  // ---------------- PROFILE ----------------
  static Future<Map<String, dynamic>?> me() async {
    try {
      final headers = await _authHeaders();
      final res = await http
          .get(Uri.parse("$authUrl/me"), headers: headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['data']['user'];
      } else {
        print("Profile fetch failed: ${res.body}");
      }
    } catch (e) {
      print("Me error: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> updateProfile(
      Map<String, dynamic> updates) async {
    try {
      final headers = await _authHeaders();
      final res = await http.put(
        Uri.parse("$authUrl/me"),
        headers: {...headers, "Content-Type": "application/json"},
        body: jsonEncode(_sanitizeBody(updates)),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        final userData = data['data'];
        if (userData != null) {
          await prefs.setString('userData', jsonEncode(userData));
          if (userData['name'] != null) {
            await prefs.setString('name', userData['name'].toString());
          }
          if (userData['email'] != null) {
            await prefs.setString('email', userData['email'].toString());
          }
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
    try {
      // ✅ Force category to match backend accepted values
      final validCategories = ["Report", "Prescription", "Bill", "Insurance"];
      final normalizedCategory =
          validCategories.contains(category) ? category : "Report";

      // Get authentication token
      final token = await _getToken();

      // Create Dio instance
      final dio = Dio();

      // Set up headers
      final headers = <String, dynamic>{
        'Content-Type': 'multipart/form-data',
      };

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      // ✅ Detect MIME type by file extension
      String filename = file.path.split("/").last;
      final lowerName = filename.toLowerCase();
      String mimeType = _detectMimeType(lowerName);

      // Get file size for progress tracking
      final fileSize = await file.length();

      // Notify initial progress (0%)
      if (onProgress != null) {
        onProgress(0.0);
      }

      // Use stream-based approach for better progress tracking
      final fileStream = file.openRead();
      final multipartFile = MultipartFile(
        fileStream,
        fileSize,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      );

      // Prepare form data
      final formData = FormData.fromMap({
        'file': multipartFile,
        'title': title,
        'category': normalizedCategory,
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
              print(
                  "📤 Upload progress: ${progress.toStringAsFixed(2)}% ($sent/$total bytes)");
            }
          }
        },
      );

      if (response.statusCode == 200) {
        final json = response.data;
        return Document.fromApi(json['document']);
      } else {
        print("Upload failed: ${response.data}");
        return null;
      }
    } catch (e) {
      print("Upload error: $e");
      return null;
    }
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
        final user = data?['data']?['user'];
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
        "$lostFoundUrl/upload-photo",
        data: formData,
        options: Options(
          headers: {
            if (token != null) HttpHeaders.authorizationHeader: "Bearer $token",
            "Content-Type": "multipart/form-data",
          },
        ),
      );

      if (response.statusCode == 201) {
        return response.data?["data"]?["photoUrl"]?.toString();
      }

      return null;
    } catch (e) {
      print("uploadLostFoundPhoto error: $e");
      return null;
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

    return jsonDecode(res.body) as Map<String, dynamic>;
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

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> fetchMyLostReports() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse("$lostFoundUrl/my-lost-reports"),
      headers: headers,
    );

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return decoded["data"]?["reports"] as List<dynamic>? ?? [];
    }
    return [];
  }

  // ---------------- FETCH FILES ----------------
  static Future<List<Document>> fetchMyDocs(String userId) async {
    try {
      final headers = await _authHeaders();
      final res =
          await http.get(Uri.parse("$filesUrl/user/$userId"), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final docs = data['documents'] as List;
        return docs.map((j) => Document.fromApi(j)).toList();
      } else {
        print("Fetch docs failed: ${res.body}");
      }
    } catch (e) {
      print("Fetch error: $e");
    }
    return [];
  }

  static Future<Map<String, dynamic>?> fetchGroupedDocs(String userId) async {
    try {
      final headers = await _authHeaders();
      final res = await http.get(
        Uri.parse("$filesUrl/user/$userId/grouped"),
        headers: headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        print("Grouped fetch failed: ${res.body}");
      }
    } catch (e) {
      print("Grouped fetch error: $e");
    }
    return null;
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
        final token = data['data']['token'];
        final user = data['data']['user'];

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("authToken", token);
          await prefs.setString("userId", user['id']?.toString() ?? "");
          await prefs.setString("email", user['email']?.toString() ?? "");
          await prefs.setString("name", user['name']?.toString() ?? "Patient");
          await prefs.setString("userData", jsonEncode(user));
          await prefs.setString(
              "activeProfileId", user['id']?.toString() ?? "");
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
      return (data["threads"] as List)
          .whereType<Map>()
          .map((entry) => entry.map(
                (key, value) => MapEntry(key.toString(), value),
              ))
          .toList(growable: false);
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
    final cacheKey = normalizedPlacement.isEmpty ? "ALL" : normalizedPlacement;

    if (!forceRefresh) {
      final cached = _adsCache[cacheKey];
      if (cached != null && cached.isValid) {
        return cached.value;
      }
    }

    try {
      final uri = Uri.parse("$publicUrl/ads").replace(
        queryParameters: normalizedPlacement.isEmpty
            ? null
            : {"placement": normalizedPlacement},
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
      final uri = Uri.parse("$publicUrl/products").replace(
        queryParameters: normalizedCategory.isEmpty
            ? null
            : {"category": normalizedCategory},
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

class _TimedCacheEntry<T> {
  final T value;
  final DateTime expiresAt;

  const _TimedCacheEntry({
    required this.value,
    required this.expiresAt,
  });

  bool get isValid => DateTime.now().isBefore(expiresAt);
}
