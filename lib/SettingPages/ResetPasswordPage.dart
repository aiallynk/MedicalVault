import 'package:flutter/material.dart';
import '../api_service.dart';

class ResetPasswordPage extends StatefulWidget {
  final String? token;
  const ResetPasswordPage({super.key, this.token});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _extractTokenFromRoute(BuildContext context) {
    // If token passed directly use it, else try to read from query params
    if (widget.token != null && widget.token!.isNotEmpty) return widget.token;
    final uri = Uri.base; // works for web or deep links
    final token = uri.queryParameters['token'];
    return token;
  }

  Future<void> _submit() async {
    final token = _extractTokenFromRoute(context);
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Reset token missing. Open the link from email.')),
      );
      return;
    }
    final pw = _passwordController.text;
    final cpw = _confirmController.text;
    if (pw.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    if (pw != cpw) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _submitting = true;
    });

    final result =
        await ApiService.resetPassword(token: token, newPassword: pw);
    if (!mounted) return;
    if (!mounted) return;
    setState(() {
      _submitting = false;
    });

    if (result != null && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ??
              'Password reset successfully. Please sign in.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result?['message'] ??
              'Failed to reset password. The link may be expired.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Create a new password',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Reset Password'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
