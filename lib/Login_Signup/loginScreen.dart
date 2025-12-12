import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hello/BottomNavigationBar/dashboard1.dart';
import 'package:hello/Login_Signup/SignUp.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hello/api_service.dart'; // 👈 Added
import 'package:hello/SettingPages/ForgotPasswordPage.dart';
import 'package:hello/Login_Signup/VerifyEmailPage.dart';
import 'package:hello/Login_Signup/google_login.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  static const String baseUrl = "https://backend-medicalvault.onrender.com/api";

  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    try {
      final url = Uri.parse("$baseUrl/auth/login");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 👇 Save the session token in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'token', data['token']); // ✅ Use same key as ApiService
        await prefs.setString(
            'userData', jsonEncode(data['user'])); // ✅ Save user data

        return data["user"];
      } else {
        print("Login failed: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error logging in: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Navigate back to WelcomeScreen instead of exiting app
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback to shield icon if image fails to load
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.shield,
                                  color: Colors.blue,
                                  size: 40,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Medical Vault',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Securely access your Medical data.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: 'Email',
                    fillColor: Theme.of(context).cardColor,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    fillColor: Theme.of(context).cardColor,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(0.6),
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Forgot Password Button
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordPage(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Theme.of(context).primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoggingIn
                        ? null
                        : () async {
                            setState(() {
                              _isLoggingIn = true;
                            });

                            try {
                              final result = await ApiService.login(
                                _emailController.text.trim(),
                                _passwordController.text.trim(),
                              );

                              if (result != null) {
                                final emailVerified = (result['user']
                                            ?['emailVerified'] ??
                                        result['emailVerified']) ==
                                    true;
                                if (!emailVerified) {
                                  // Prompt to verify email
                                  final verified = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const VerifyEmailPage(),
                                    ),
                                  );
                                  if (verified == true && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              '✅ Email verified. Please proceed.')),
                                    );
                                  }
                                }
                                // ✅ Get user data from SharedPreferences after login
                                final prefs =
                                    await SharedPreferences.getInstance();
                                final userDataString =
                                    prefs.getString('userData');
                                final userData = userDataString != null
                                    ? jsonDecode(userDataString)
                                    : <String, dynamic>{};

                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        Dashboard1(userData: userData),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("❌ Login failed")),
                                );
                              }
                            } finally {
                              if (!mounted) return;
                              setState(() {
                                _isLoggingIn = false;
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoggingIn
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Logging you in...',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.white),
                              ),
                            ],
                          )
                        : const Text(
                            'Log In',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                // Google Login Button
                OutlinedButton(
                  onPressed: _isLoggingIn
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const GoogleLoginScreen()),
                          );
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                    backgroundColor: Theme.of(context).cardColor,
                    side: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white24
                          : Colors.black12,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_circle,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                      const SizedBox(width: 10),
                      const Text('Log in with Google'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withOpacity(0.8),
                            )),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SignUpPage()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Sign up',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
