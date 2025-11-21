import 'package:flutter/material.dart';
import '../api_service.dart';
import '../localization/app_localizations.dart';

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
    if (widget.token != null && widget.token!.isNotEmpty) return widget.token;
    final uri = Uri.base;
    return uri.queryParameters['token'];
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final token = _extractTokenFromRoute(context);
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('resetPassword.missingToken'))),
      );
      return;
    }
    final pw = _passwordController.text;
    final cpw = _confirmController.text;
    if (pw.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('resetPassword.minLength'))),
      );
      return;
    }
    if (pw != cpw) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('resetPassword.mismatch'))),
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
    setState(() {
      _submitting = false;
    });

    if (result != null && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              result['message'] ?? l10n.t('resetPassword.successFallback')),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              result?['message'] ?? l10n.t('resetPassword.failureFallback')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('resetPassword.title'))),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.t('resetPassword.subtitle'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.t('resetPassword.newPassword'),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.t('resetPassword.confirmPassword'),
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
                    : Text(l10n.t('resetPassword.button')),
              ),
            )
          ],
        ),
      ),
    );
  }
}
