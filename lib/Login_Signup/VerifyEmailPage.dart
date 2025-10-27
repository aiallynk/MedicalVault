import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hello/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerifyEmailPage extends StatefulWidget {
  final String? incomingToken; // tokenId.secret from deep link
  const VerifyEmailPage({super.key, this.incomingToken});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final TextEditingController _codeCtrl = TextEditingController();
  bool _isVerifying = false;
  String? _email;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadEmail();
    // If deep link brings token, auto-verify
    if (widget.incomingToken != null && widget.incomingToken!.contains('.')) {
      _verifyWithToken(widget.incomingToken!);
    }
  }

  Future<void> _loadEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _email = prefs.getString('email');
    });
  }

  Future<void> _verifyWithToken(String token) async {
    if (_isVerifying) return;
    setState(() {
      _isVerifying = true;
      _status = null;
    });
    final res = await ApiService.verifyEmailWithToken(token);
    if (!mounted) return;
    setState(() {
      _isVerifying = false;
    });
    if (!mounted) return;
    if (res != null && res['success'] == true) {
      setState(() {
        _status = 'Email verified successfully';
      });
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() {
        _status = res?['message'] ?? 'Verification failed';
      });
    }
  }

  Future<void> _verifyWithCode() async {
    if (_isVerifying) return;
    final email = _email;
    final code = _codeCtrl.text.trim();
    if (email == null || email.isEmpty || code.isEmpty) {
      setState(() => _status = 'Please enter the 6-digit code');
      return;
    }
    if (!mounted) return;
    setState(() {
      _isVerifying = true;
      _status = null;
    });
    final res = await ApiService.verifyEmailWithCode(email: email, code: code);
    if (!mounted) return;
    setState(() {
      _isVerifying = false;
    });
    if (!mounted) return;
    if (res != null && res['success'] == true) {
      setState(() {
        _status = 'Email verified successfully';
      });
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() {
        _status = res?['message'] ?? 'Invalid code';
      });
    }
  }

  Future<void> _resend() async {
    final email = _email;
    if (email == null || email.isEmpty) {
      setState(() => _status = 'No email found');
      return;
    }
    final res = await ApiService.resendVerification(email);
    if (!mounted) return;
    setState(() {
      _status = (res?['success'] == true)
          ? 'Verification email resent'
          : (res?['message']?.toString() ?? 'Resend failed');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              _email != null
                  ? 'A verification link and code were sent to\n$_email'
                  : 'A verification link and code were sent to your email',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: '6-digit code',
                hintText: 'Enter the code from email',
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 8),
            if (_status != null)
              Text(
                _status!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _status!.toLowerCase().contains('success')
                        ? Colors.green
                        : Colors.red),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isVerifying ? null : _verifyWithCode,
              child: _isVerifying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify with code'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _resend,
              child: const Text('Resend verification'),
            ),
          ],
        ),
      ),
    );
  }
}
