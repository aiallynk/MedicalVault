import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hello/BottomNavigationBar/dashboard1.dart';
import 'package:hello/Notifications/fcm_service.dart';

class GoogleLoginScreen extends StatefulWidget {
  const GoogleLoginScreen({super.key});

  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  static const String backendEndpoint =
      'https://backend-medicalvault.onrender.com/api/auth/google';

  // For Android: clientId is null, it reads from google-services.json
  // For iOS: You need to set the iOS client ID from Firebase Console
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email', 'profile'],
  );

  bool _isLoading = false;
  String? _statusMessage;
  Map<String, dynamic>? _backendResponse;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Starting Google Sign-In...';
      _backendResponse = null;
    });

    try {
      // Sign out first to force account picker to show every time
      await _googleSignIn.signOut();

      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        setState(() {
          _statusMessage = 'Sign-in cancelled by user.';
        });
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        setState(() {
          _statusMessage = 'Failed to obtain ID token from Google.';
        });
        return;
      }

      setState(() {
        _statusMessage = 'Logging you in...';
      });

      final response = await http.post(
        Uri.parse(backendEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        // Check backend success flag
        if (data['success'] == true) {
          // Store session to match the app's login expectations
          final prefs = await SharedPreferences.getInstance();
          final user = data['user'] ?? <String, dynamic>{};
          final token = data['token'] ?? '';

          await prefs.setString('authToken', token);
          await prefs.setString('userId', (user['id'] ?? '').toString());
          await prefs.setString('email', (user['email'] ?? '').toString());
          await prefs.setString('name', (user['name'] ?? 'Patient').toString());
          await prefs.setString('userData', jsonEncode(user));

          // Register FCM token now that we have an auth token
          await FCMService().registerToken();

          if (!mounted) return;

          // Navigate to Dashboard
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  Dashboard1(userData: Map<String, dynamic>.from(user)),
            ),
            (route) => false,
          );
        } else {
          setState(() {
            _statusMessage = data['message'] ?? 'Login failed';
            _backendResponse = data;
          });
        }
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _statusMessage =
              errorData['message'] ?? 'Backend error (${response.statusCode})';
          _backendResponse = {
            'status': response.statusCode,
            'body': response.body,
          };
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Network or sign-in error: $e';
        _backendResponse = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildGoogleButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return OutlinedButton(
      onPressed: _isLoading ? null : _handleGoogleSignIn,
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? Colors.white : Colors.black87,
        backgroundColor: Theme.of(context).cardColor,
        side: BorderSide(
            color: isDark ? Colors.white24 : Colors.black12, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_circle,
              color: isDark ? Colors.white : Colors.black87),
          const SizedBox(width: 10),
          if (_isLoading) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            const Text('Signing in...'),
          ] else
            const Text('Sign up / Log in with Google'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log in with Google'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const SizedBox(height: 24),
              Text(
                'Authenticate using your Google account',
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Sign in button (supports light/dark)
              _buildGoogleButton(context),

              const SizedBox(height: 24),

              // Status
              if (_statusMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: textTheme.bodyMedium,
                  ),
                ),

              const SizedBox(height: 16),

              // Backend response
              if (_backendResponse != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    const JsonEncoder.withIndent('  ')
                        .convert(_backendResponse),
                    style: textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
