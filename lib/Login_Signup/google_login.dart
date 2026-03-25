import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hello/api_service.dart';
import 'package:hello/Login_Signup/login_success_screen.dart';
import 'package:hello/services/session_conflict_service.dart';

class GoogleLoginScreen extends StatefulWidget {
  const GoogleLoginScreen({super.key});

  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  // For Android: clientId is null, it reads from google-services.json
  // For iOS: You need to set the iOS client ID from Firebase Console
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'profile',
      'https://www.googleapis.com/auth/user.birthday.read',
    ],
  );

  bool _isLoading = false;
  String? _statusMessage;
  Map<String, dynamic>? _backendResponse;

  Future<void> _animateGoogleLoginSuccessAndNavigate(
    Map<String, dynamic> userData,
  ) async {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        settings: const RouteSettings(name: '/login_success'),
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) => LoginSuccessScreen(
          userData: userData,
          title: 'Google Login Successful',
          subtitle: 'Securing your vault and loading dashboard...',
          clearStackOnComplete: true,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
      (route) => false,
    );
  }

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
      final String? accessToken = auth.accessToken;

      if (idToken == null) {
        setState(() {
          _statusMessage = 'Failed to obtain ID token from Google.';
        });
        return;
      }

      setState(() {
        _statusMessage = 'Logging you in...';
      });

      // Optionally fetch age from Google People API if permitted
      int? googleAge;
      try {
        if (accessToken != null && accessToken.isNotEmpty) {
          googleAge = await _fetchAgeFromGoogle(accessToken);
        }
      } catch (_) {
        // Ignore People API errors and continue login flow
      }

      var data = await ApiService.loginWithGoogleIdToken(idToken);
      if (!mounted) return;

      final code = (data['code'] ?? '').toString().trim().toUpperCase();
      if (data['success'] != true && code == 'LOGIN_APPROVAL_REQUIRED') {
        final attemptId = (data['loginAttemptId'] ?? '').toString().trim();
        final attemptToken = (data['attemptToken'] ?? '').toString().trim();
        if (attemptId.isNotEmpty && attemptToken.isNotEmpty) {
          setState(() {
            _statusMessage =
                'Login request sent to active device. Waiting for approval...';
          });
          data = await SessionConflictService.instance
              .waitForLoginAttemptResolution(
            loginAttemptId: attemptId,
            attemptToken: attemptToken,
          );
          if (!mounted) return;
        }
      }

      if (data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        final storedUserRaw = prefs.getString('userData');
        final storedUser = storedUserRaw == null
            ? null
            : jsonDecode(storedUserRaw);
        final Map<String, dynamic> mergedUser = storedUser is Map
            ? Map<String, dynamic>.from(storedUser)
            : (data['user'] is Map
                ? Map<String, dynamic>.from(data['user'])
                : <String, dynamic>{});

        if ((mergedUser['age'] == null ||
                mergedUser['age'].toString().isEmpty) &&
            googleAge != null) {
          mergedUser['age'] = googleAge;
          await prefs.setString('userData', jsonEncode(mergedUser));
        }

        await SessionConflictService.instance.connectForCurrentSession();
        if (!mounted) return;
        await _animateGoogleLoginSuccessAndNavigate(mergedUser);
      } else {
        setState(() {
          _statusMessage = (data['message'] ?? 'Login failed').toString();
          _backendResponse = data;
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

  // Fetch birthday via Google People API and compute age
  Future<int?> _fetchAgeFromGoogle(String accessToken) async {
    final uri = Uri.parse(
        'https://people.googleapis.com/v1/people/me?personFields=birthdays');
    final res = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (res.statusCode != 200) return null;

    final Map<String, dynamic> body = jsonDecode(res.body);
    final List<dynamic>? birthdays = body['birthdays'] as List<dynamic>?;
    if (birthdays == null || birthdays.isEmpty) return null;

    Map<String, dynamic>? chosen;
    for (final entry in birthdays) {
      final date =
          (entry as Map<String, dynamic>)['date'] as Map<String, dynamic>?;
      if (date == null) continue;
      if (date.containsKey('year') &&
          date.containsKey('month') &&
          date.containsKey('day')) {
        chosen = date;
        break;
      }
    }
    chosen ??= birthdays.first['date'] as Map<String, dynamic>?;
    if (chosen == null ||
        !chosen.containsKey('year') ||
        !chosen.containsKey('month') ||
        !chosen.containsKey('day')) {
      return null;
    }

    final dob = DateTime(
      chosen['year'] as int,
      chosen['month'] as int,
      chosen['day'] as int,
    );
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
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
      body: Stack(
        children: [
          SafeArea(
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
                  _buildGoogleButton(context),
                  const SizedBox(height: 24),
                  if (_statusMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.06),
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
        ],
      ),
    );
  }
}
