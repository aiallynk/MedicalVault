import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:hello/Login_Signup/loginScreen.dart';
import 'package:hello/Login_Signup/logout_service.dart';
import 'package:hello/api_service.dart';
import 'package:hello/core/navigation/app_navigator.dart';

class SessionConflictService {
  SessionConflictService._internal();
  static final SessionConflictService instance =
      SessionConflictService._internal();

  static const String _pendingNoticeKey = 'pending_forced_logout_notice';
  static const String _defaultForcedLogoutMessage =
      'You have been logged out due to login from another device';

  StreamSubscription<Map<String, String>>? _apiSessionSubscription;
  WebSocketChannel? _sessionChannel;
  StreamSubscription<dynamic>? _sessionStreamSubscription;
  Timer? _reconnectTimer;
  Timer? _sessionHealthTimer;
  Timer? _heartbeatTimer;
  bool _initialized = false;
  bool _isHandlingForcedLogout = false;
  bool _isLoginAttemptDialogVisible = false;
  bool _isForcedLogoutDialogVisible = false;
  String _activeAttemptId = '';

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _apiSessionSubscription = ApiService.sessionEvents.listen((event) {
      final type = (event['type'] ?? '').trim().toLowerCase();
      if (type == 'session_invalid') {
        final message = event['message']?.trim() ?? _defaultForcedLogoutMessage;
        unawaited(_handleForcedLogout(message));
      }
    });
    await connectForCurrentSession();
    _startSessionHealthPolling();
    unawaited(showPendingForcedLogoutNoticeIfAny());
  }

  Future<void> connectForCurrentSession() async {
    await _sessionStreamSubscription?.cancel();
    _sessionStreamSubscription = null;
    await _sessionChannel?.sink.close();
    _sessionChannel = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final token = await ApiService.getToken();
    if (token == null || token.trim().isEmpty) {
      return;
    }
    final deviceId = await ApiService.getOrCreateDeviceId();

    try {
      final channel = WebSocketChannel.connect(
        ApiService.authSessionWebSocketUri(
          token: token,
          deviceId: deviceId,
        ),
      );
      try {
        await channel.ready.timeout(const Duration(seconds: 8));
      } catch (_) {
        await channel.sink.close();
        _scheduleReconnect();
        return;
      }

      _sessionChannel = channel;
      _sessionStreamSubscription = channel.stream.listen(
        _handleSessionSocketMessage,
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isHandlingForcedLogout) return;
    if (_reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      unawaited(connectForCurrentSession());
    });
  }

  void _startSessionHealthPolling() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_runHeartbeat());
    });
    unawaited(_runHeartbeat());

    _sessionHealthTimer?.cancel();
    _sessionHealthTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_runSessionHealthCheck());
    });
    unawaited(_runSessionHealthCheck());
  }

  Future<void> _runHeartbeat() async {
    if (_isHandlingForcedLogout) return;
    final token = await ApiService.getToken();
    if (token == null || token.trim().isEmpty) return;
    await ApiService.sendSessionHeartbeat();
  }

  Future<void> _runSessionHealthCheck() async {
    if (_isHandlingForcedLogout) return;
    final token = await ApiService.getToken();
    if (token == null || token.trim().isEmpty) return;
    try {
      await ApiService.me();
    } catch (_) {
      // Ignore transient health-check failures.
    }
  }

  void _handleSessionSocketMessage(dynamic raw) {
    Map<String, dynamic>? message;
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is Map<String, dynamic>) {
        message = decoded;
      } else if (decoded is Map) {
        message = decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return;
    }
    if (message == null) return;

    final type = (message['type'] ?? '').toString().trim().toLowerCase();
    switch (type) {
      case 'login_attempt':
        unawaited(_showLoginAttemptDialog(message));
        break;
      case 'session_invalidated':
        final forcedMessage =
            (message['message'] ?? _defaultForcedLogoutMessage).toString();
        unawaited(_handleForcedLogout(forcedMessage));
        break;
      default:
        break;
    }
  }

  Future<void> _showLoginAttemptDialog(Map<String, dynamic> payload) async {
    if (_isLoginAttemptDialogVisible || _isHandlingForcedLogout) return;
    final attemptId = (payload['attemptId'] ?? '').toString().trim();
    if (attemptId.isEmpty) return;
    final requestedDeviceId =
        (payload['requestedDeviceId'] ?? '').toString().trim();
    if (requestedDeviceId.isNotEmpty) {
      final currentDeviceId = (await ApiService.getOrCreateDeviceId()).trim();
      if (currentDeviceId.isNotEmpty && currentDeviceId == requestedDeviceId) {
        return;
      }
    }
    if (_activeAttemptId == attemptId) return;
    final requestedDeviceInfo = (payload['requestedDeviceInfo'] ??
            payload['requestedDeviceLabel'] ??
            '')
        .toString()
        .trim();
    final requestedIp = (payload['requestedIp'] ?? '').toString().trim();
    final messageBuffer =
        StringBuffer('Another device is trying to login to your account.');
    if (requestedDeviceInfo.isNotEmpty) {
      messageBuffer.write('\n\nRequested device: $requestedDeviceInfo');
    }
    if (requestedIp.isNotEmpty) {
      messageBuffer.write('\nIP: $requestedIp');
    }
    final dialogMessage = messageBuffer.toString();

    final context = appNavigatorKey.currentContext;
    if (context == null) return;

    _isLoginAttemptDialogVisible = true;
    _activeAttemptId = attemptId;
    bool submitting = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('Session Conflict'),
                  content: Text(dialogMessage),
                  actions: [
                    TextButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              setState(() => submitting = true);
                              final success =
                                  await ApiService.respondToLoginAttempt(
                                loginAttemptId: attemptId,
                                approve: false,
                              );
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                              if (!success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Unable to deny login request'),
                                  ),
                                );
                              }
                            },
                      child: const Text('Deny'),
                    ),
                    ElevatedButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              setState(() => submitting = true);
                              final success =
                                  await ApiService.respondToLoginAttempt(
                                loginAttemptId: attemptId,
                                approve: true,
                              );
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                              if (success) {
                                await _handleForcedLogout(
                                  _defaultForcedLogoutMessage,
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Unable to approve login request'),
                                  ),
                                );
                              }
                            },
                      child: const Text('Allow'),
                    ),
                  ],
                );
              },
            ),
          );
        },
      );
    } finally {
      _activeAttemptId = '';
      _isLoginAttemptDialogVisible = false;
    }
  }

  Future<Map<String, dynamic>> waitForLoginAttemptResolution({
    required String loginAttemptId,
    required String attemptToken,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    WebSocketChannel? channel;
    StreamSubscription<dynamic>? subscription;
    Timer? timeoutTimer;

    Future<void> finish(Map<String, dynamic> value) async {
      if (completer.isCompleted) return;
      timeoutTimer?.cancel();
      await subscription?.cancel();
      await channel?.sink.close();
      completer.complete(value);
    }

    try {
      final deviceId = await ApiService.getOrCreateDeviceId();
      channel = WebSocketChannel.connect(
        ApiService.authSessionWebSocketUri(
          attemptToken: attemptToken,
          deviceId: deviceId,
        ),
      );
      try {
        await channel.ready.timeout(const Duration(seconds: 8));
      } catch (_) {
        await finish({
          'success': false,
          'message': 'Unable to connect for login approval',
          'statusCode': 0,
        });
        return completer.future;
      }

      timeoutTimer = Timer(timeout, () {
        unawaited(finish({
          'success': false,
          'message': 'Login approval timed out',
          'code': 'LOGIN_APPROVAL_TIMEOUT',
          'statusCode': 408,
        }));
      });

      subscription = channel.stream.listen(
        (raw) async {
          Map<String, dynamic>? payload;
          try {
            final decoded = jsonDecode(raw.toString());
            if (decoded is Map<String, dynamic>) {
              payload = decoded;
            } else if (decoded is Map) {
              payload =
                  decoded.map((key, value) => MapEntry(key.toString(), value));
            }
          } catch (_) {
            return;
          }
          if (payload == null) return;

          final type = (payload['type'] ?? '').toString().trim().toLowerCase();
          if (type == 'login_denied') {
            await finish({
              'success': false,
              'message': 'Login denied by active session',
              'code': 'LOGIN_DENIED_BY_ACTIVE_SESSION',
              'statusCode': 403,
            });
            return;
          }

          if (type == 'login_approved') {
            final finalize = await ApiService.finalizePendingLogin(
              loginAttemptId: loginAttemptId,
              attemptToken: attemptToken,
            );
            await finish(finalize);
          }
        },
        onDone: () async {
          await finish({
            'success': false,
            'message': 'Approval channel disconnected',
            'statusCode': 0,
          });
        },
        onError: (_) async {
          await finish({
            'success': false,
            'message': 'Approval channel error',
            'statusCode': 0,
          });
        },
        cancelOnError: true,
      );
    } catch (_) {
      await finish({
        'success': false,
        'message': 'Unable to connect for login approval',
        'statusCode': 0,
      });
    }

    return completer.future;
  }

  Future<void> _handleForcedLogout(String message) async {
    if (_isHandlingForcedLogout) return;
    _isHandlingForcedLogout = true;
    await _persistPendingNotice(message);

    try {
      await LogoutService().logout();
      await _sessionStreamSubscription?.cancel();
      _sessionStreamSubscription = null;
      await _sessionChannel?.sink.close();
      _sessionChannel = null;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _sessionHealthTimer?.cancel();
      _sessionHealthTimer = null;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;

      final navigator = appNavigatorKey.currentState;
      if (navigator != null) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/login'),
            builder: (_) => const LoginScreen(),
          ),
          (route) => false,
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 250));
      await showPendingForcedLogoutNoticeIfAny();
    } finally {
      _isHandlingForcedLogout = false;
    }
  }

  Future<void> _persistPendingNotice(String message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingNoticeKey,
      message.trim().isEmpty ? _defaultForcedLogoutMessage : message.trim(),
    );
  }

  Future<void> showPendingForcedLogoutNoticeIfAny() async {
    if (_isForcedLogoutDialogVisible) return;
    final prefs = await SharedPreferences.getInstance();
    final message = prefs.getString(_pendingNoticeKey)?.trim();
    if (message == null || message.isEmpty) return;
    final context = appNavigatorKey.currentContext;
    if (context == null) return;

    _isForcedLogoutDialogVisible = true;
    try {
      await prefs.remove(_pendingNoticeKey);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text('Logged Out'),
              content: Text(message),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      _isForcedLogoutDialogVisible = false;
    }
  }

  Future<void> dispose() async {
    await _apiSessionSubscription?.cancel();
    _apiSessionSubscription = null;
    await _sessionStreamSubscription?.cancel();
    _sessionStreamSubscription = null;
    await _sessionChannel?.sink.close();
    _sessionChannel = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _sessionHealthTimer?.cancel();
    _sessionHealthTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _initialized = false;
  }
}
