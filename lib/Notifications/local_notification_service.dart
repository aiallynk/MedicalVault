import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Builds a real OS notification with a WhatsApp-style round sender avatar
/// (Android "large icon" / iOS notification attachment) for chat messages
/// received while the app is in the foreground.
///
/// Scoped to foreground chat notifications only: FCM's own automatic
/// display already handles background/terminated notifications, and this
/// service does not attempt to replace that path.
class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _notificationIdCounter = 0;

  static const String _chatChannelId = 'medical_vault_chat';
  static const String _chatChannelName = 'Chat messages';
  static const String _chatChannelDescription =
      'Notifications for new chat messages from doctors and patients';

  Future<void> initialize({
    void Function(String? payload)? onNotificationTap,
  }) async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _chatChannelId,
        _chatChannelName,
        description: _chatChannelDescription,
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  /// Shows a chat-message notification with [avatarUrl] as the large icon
  /// when available; falls back to a plain notification (no large icon) if
  /// the avatar can't be downloaded, so a slow/failed image fetch never
  /// blocks the notification from appearing.
  Future<void> showChatMessageNotification({
    required String title,
    required String body,
    String? avatarUrl,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    final largeIconPath = await _downloadToTempFile(avatarUrl);

    final androidDetails = AndroidNotificationDetails(
      _chatChannelId,
      _chatChannelName,
      channelDescription: _chatChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: const DefaultStyleInformation(true, true),
      largeIcon: largeIconPath != null
          ? FilePathAndroidBitmap(largeIconPath)
          : null,
    );
    final iosDetails = DarwinNotificationDetails(
      attachments: largeIconPath != null
          ? [DarwinNotificationAttachment(largeIconPath)]
          : null,
    );

    await _plugin.show(
      id: _nextNotificationId(),
      title: title,
      body: body,
      notificationDetails:
          NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  int _nextNotificationId() {
    _notificationIdCounter =
        (_notificationIdCounter + 1) % 0x7fffffff; // stay within a 32-bit int
    return _notificationIdCounter;
  }

  /// Downloads [url] to a temp file for use as a large icon/attachment.
  /// Returns null (never throws) on any failure - a missing avatar must
  /// never prevent the notification text itself from showing.
  Future<String?> _downloadToTempFile(String? url) async {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty || !trimmed.startsWith('http')) return null;
    try {
      final response = await http
          .get(Uri.parse(trimmed))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      final dir = await getTemporaryDirectory();
      final extension = _guessExtension(response.headers['content-type']);
      final file = File(
        '${dir.path}/chat_avatar_${DateTime.now().millisecondsSinceEpoch}$extension',
      );
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return file.path;
    } catch (e) {
      if (kDebugMode) {
        print('LocalNotificationService: avatar download failed: $e');
      }
      return null;
    }
  }

  String _guessExtension(String? contentType) {
    final type = (contentType ?? '').toLowerCase();
    if (type.contains('png')) return '.png';
    if (type.contains('webp')) return '.webp';
    return '.jpg';
  }
}
