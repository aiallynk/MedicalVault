import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:hello/Notifications/fcm_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'Document_model.dart';
import 'package:dio/dio.dart';
import 'package:hello/helpers/google_auth_helper.dart';

class ApiService {
  static const String baseUrl = "https://backend-medicalvault.onrender.com/api";
  static const String authUrl = "$baseUrl/auth";
  static const String filesUrl = "$baseUrl/files";
  static const String qrUrl = "$baseUrl/qr";
  static const String aiUrl = "$baseUrl/ai";

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
      final res = await http.get(Uri.parse("$authUrl/me"), headers: headers);
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

      // Prepare form data
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: filename,
          contentType: DioMediaType.parse(mimeType),
        ),
        'title': title,
        'category': normalizedCategory,
        if (notes != null) 'notes': notes,
        if (date != null) 'date': date,
      });

      // Make the upload request with real progress tracking
      final response = await dio.post(
        "$filesUrl/upload",
        data: formData,
        options: Options(
          headers: headers,
          sendTimeout: const Duration(minutes: 5), // 5 minute timeout
          receiveTimeout: const Duration(minutes: 5),
        ),
        onSendProgress: (sent, total) {
          // This provides REAL upload progress
          if (onProgress != null && total > 0) {
            final progress = (sent / total) * 100;
            onProgress(progress.clamp(0.0, 100.0));
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
      final res =
          await http.post(Uri.parse("$qrUrl/generate"), headers: headers);
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
