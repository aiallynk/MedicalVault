import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hello/Login_Signup/SignUp.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hello/api_service.dart';
import 'package:hello/Login_Signup/login_success_screen.dart';
import 'package:hello/SettingPages/ForgotPasswordPage.dart';
import 'package:hello/Login_Signup/VerifyEmailPage.dart';
import 'package:hello/Login_Signup/google_login.dart';
import 'package:hello/services/secure_token_storage.dart';
import 'package:hello/services/session_conflict_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoggingIn = false;
  bool _animateIn = false;

  static final String baseUrl = ApiService.baseUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _animateIn = true;
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    try {
      final url = Uri.parse('$baseUrl/auth/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = ApiService.extractTokenFromResponseData(
          data is Map
              ? data.map((key, value) => MapEntry(key.toString(), value))
              : null,
        );

        final prefs = await SharedPreferences.getInstance();
        if (token == null) {
          await SecureTokenStorage.clearToken();
          debugPrint('Login failed: token missing in response');
          return null;
        }

        await SecureTokenStorage.saveToken(token);
        final refreshToken = (data['refreshToken'] ?? '').toString().trim();
        if (refreshToken.isNotEmpty) {
          await SecureTokenStorage.saveRefreshToken(refreshToken);
        }
        await prefs.setString('userData', jsonEncode(data['user']));
        final user = data['user'];
        if (user is Map) {
          await prefs.setString(
            'userId',
            (user['id'] ?? user['_id'] ?? '').toString(),
          );
        }

        return data['user'];
      } else {
        debugPrint('Login failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error logging in: $e');
      return null;
    }
  }

  Future<void> _clearStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    await SecureTokenStorage.clearToken();
    await prefs.remove('userData');
    await prefs.remove('userId');
    await prefs.remove('email');
    await prefs.remove('name');
  }

  Future<void> _animateLoginSuccessAndNavigate(
    Map<String, dynamic> userData,
  ) async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        settings: const RouteSettings(name: '/login_success'),
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) => LoginSuccessScreen(
          userData: userData,
          title: 'Login Successful',
          subtitle: 'Preparing your dashboard...',
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
    );
  }

  Widget _animatedSection({required int order, required Widget child}) {
    final duration = Duration(milliseconds: 340 + (order * 140));
    return AnimatedOpacity(
      opacity: _animateIn ? 1 : 0,
      duration: duration,
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _animateIn ? Offset.zero : const Offset(0, 0.08),
        duration: duration,
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String label,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(prefixIcon, color: colorScheme.primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: theme.brightness == Brightness.dark
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
          : colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.35),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.35),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: colorScheme.primary,
          width: 1.7,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDarkMode ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: Scaffold(
          backgroundColor:
              isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF0F8FF),
          extendBody: true,
          resizeToAvoidBottomInset: true,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.surface,
                        isDarkMode
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF0F8FF),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -110,
                right: -70,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Positioned(
                bottom: -90,
                left: -60,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.secondary.withValues(alpha: 0.10),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _animatedSection(
                              order: 0,
                              child: const SizedBox(height: 20),
                            ),
                            _animatedSection(
                        order: 1,
                        child: Center(
                          child: Column(
                            children: [
                              Hero(
                                tag: 'auth-logo',
                                child: Container(
                                  width: 86,
                                  height: 86,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    color: colorScheme.primaryContainer
                                        .withValues(alpha: 0.8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorScheme.primary
                                            .withValues(alpha: 0.25),
                                        blurRadius: 22,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Image.asset(
                                      'assets/icon/app_icon.png',
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Icon(
                                          Icons.health_and_safety,
                                          color: colorScheme.primary,
                                          size: 42,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Welcome Back',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sign in to access your medical records securely.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _animatedSection(
                        order: 2,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: theme.cardColor.withValues(alpha: 0.95),
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                    alpha: isDarkMode ? 0.32 : 0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: _inputDecoration(
                                  context: context,
                                  label: 'Email Address',
                                  prefixIcon: Icons.mail_outline_rounded,
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                textInputAction: TextInputAction.done,
                                decoration: _inputDecoration(
                                  context: context,
                                  label: 'Password',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible =
                                            !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        settings: const RouteSettings(
                                            name: '/forgot_password'),
                                        builder: (_) =>
                                            const ForgotPasswordPage(),
                                      ),
                                    );
                                  },
                                  child: const Text('Forgot Password?'),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoggingIn
                                      ? null
                                      : () async {
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          final navigator =
                                              Navigator.of(context);
                                          setState(() {
                                            _isLoggingIn = true;
                                          });

                                          try {
                                            var result = await ApiService.login(
                                              _emailController.text.trim(),
                                              _passwordController.text.trim(),
                                            );
                                            if (!mounted) return;

                                            final code = (result['code'] ?? '')
                                                .toString()
                                                .trim()
                                                .toUpperCase();
                                            if (result['success'] != true &&
                                                code ==
                                                    'LOGIN_APPROVAL_REQUIRED') {
                                              final attemptId =
                                                  (result['loginAttemptId'] ??
                                                          '')
                                                      .toString()
                                                      .trim();
                                              final attemptToken =
                                                  (result['attemptToken'] ?? '')
                                                      .toString()
                                                      .trim();
                                              if (attemptId.isNotEmpty &&
                                                  attemptToken.isNotEmpty) {
                                                messenger.showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Login request sent to active device. Waiting for approval...',
                                                    ),
                                                  ),
                                                );
                                                result =
                                                    await SessionConflictService
                                                        .instance
                                                        .waitForLoginAttemptResolution(
                                                  loginAttemptId: attemptId,
                                                  attemptToken: attemptToken,
                                                );
                                                if (!mounted) return;
                                              }
                                            }

                                            if (result['success'] == true) {
                                              final emailVerified = (result[
                                                              'user']
                                                          ?['emailVerified'] ??
                                                      result[
                                                          'emailVerified']) ==
                                                  true;
                                              if (!emailVerified) {
                                                final verified =
                                                    await navigator.push(
                                                  MaterialPageRoute(
                                                    settings:
                                                        const RouteSettings(
                                                            name: '/verify'),
                                                    builder: (_) =>
                                                        VerifyEmailPage(
                                                      prefilledEmail:
                                                          _emailController.text
                                                              .trim(),
                                                    ),
                                                  ),
                                                );
                                                if (!mounted) return;
                                                if (verified != true) {
                                                  await _clearStoredSession();
                                                  if (!mounted) return;
                                                  messenger.showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Verify your 6-digit code to continue.',
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }
                                                messenger.showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Email verified. Please proceed.',
                                                    ),
                                                  ),
                                                );
                                              }
                                              final prefs =
                                                  await SharedPreferences
                                                      .getInstance();
                                              if (!mounted) return;
                                              final userDataString =
                                                  prefs.getString('userData');
                                              final decodedUserData =
                                                  userDataString != null
                                                      ? jsonDecode(
                                                          userDataString)
                                                      : null;
                                              final userData = decodedUserData
                                                      is Map
                                                  ? Map<String, dynamic>.from(
                                                      decodedUserData,
                                                    )
                                                  : <String, dynamic>{};

                                              await SessionConflictService
                                                  .instance
                                                  .connectForCurrentSession();
                                              await _animateLoginSuccessAndNavigate(
                                                  userData);
                                            } else {
                                              final denyCode =
                                                  (result['code'] ?? '')
                                                      .toString()
                                                      .trim()
                                                      .toUpperCase();
                                              final message = denyCode ==
                                                      'LOGIN_DENIED_BY_ACTIVE_SESSION'
                                                  ? 'Login denied by active session'
                                                  : (result['message'] ??
                                                          'Login failed')
                                                      .toString();
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text(message),
                                                ),
                                              );
                                            }
                                          } finally {
                                            if (mounted) {
                                              setState(() {
                                                _isLoggingIn = false;
                                              });
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    disabledBackgroundColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    child: _isLoggingIn
                                        ? Row(
                                            key: const ValueKey('loading'),
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                'Logging you in...',
                                                style: theme
                                                    .textTheme.titleMedium
                                                    ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Text(
                                            'Log In',
                                            key: const ValueKey('login'),
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: _isLoggingIn
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            settings: const RouteSettings(
                                                name: '/login/google'),
                                            builder: (_) =>
                                                const GoogleLoginScreen(),
                                          ),
                                        );
                                      },
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.account_circle_outlined),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        'Log in with Google',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _animatedSection(
                        order: 3,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    settings:
                                        const RouteSettings(name: '/signup'),
                                    builder: (_) => const SignUpPage(),
                                  ),
                                );
                              },
                              child: const Text('Sign up'),
                            ),
                          ],
                        ),
                      ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
