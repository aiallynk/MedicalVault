import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_manager.dart';
import 'notification_settings_service.dart';

class GlobalNotificationHandler {
  static final GlobalNotificationHandler _instance =
      GlobalNotificationHandler._internal();
  factory GlobalNotificationHandler() => _instance;
  GlobalNotificationHandler._internal();

  final NotificationManager _notificationManager = NotificationManager();
  final NotificationSettingsService _settingsService =
      NotificationSettingsService();

  // Global context for showing notifications
  static BuildContext? _globalContext;

  // Set the global context (call this in main.dart)
  static void setGlobalContext(BuildContext context) {
    _globalContext = context;
  }

  // Show session expiring notification
  Future<void> showSessionExpiringNotification() async {
    if (_globalContext == null) return;

    final isEnabled =
        await _settingsService.isNotificationEnabled('sessionExpiring');
    if (!isEnabled) return;

    _notificationManager.showSessionExpiringNotification(_globalContext!);
  }

  // Show appointment reminder notification
  Future<void> showAppointmentReminder(String doctorName, String time) async {
    if (_globalContext == null) return;

    final isEnabled = await _settingsService.isNotificationEnabled('reminders');
    if (!isEnabled) return;

    _notificationManager.showAppointmentReminder(
        _globalContext!, doctorName, time);
  }

  // Show system update notification
  Future<void> showSystemUpdateNotification(String version) async {
    if (_globalContext == null) return;

    final isEnabled = await _settingsService.isNotificationEnabled('system');
    if (!isEnabled) return;

    _notificationManager.showSystemUpdateNotification(_globalContext!, version);
  }

  // Show advertisement notification
  Future<void> showAdvertisementNotification(
      String title, String message) async {
    if (_globalContext == null) return;

    final isEnabled = await _settingsService.isNotificationEnabled('system');
    if (!isEnabled) return;

    _notificationManager.showAdvertisementNotification(
        _globalContext!, title, message);
  }

  // Show instruction notification
  Future<void> showInstructionNotification(String title, String message) async {
    if (_globalContext == null) return;

    final isEnabled = await _settingsService.isNotificationEnabled('system');
    if (!isEnabled) return;

    _notificationManager.showInstructionNotification(
        _globalContext!, title, message);
  }

  // Show general reminder notification
  Future<void> showReminderNotification(String title, String message) async {
    if (_globalContext == null) return;

    final isEnabled = await _settingsService.isNotificationEnabled('reminders');
    if (!isEnabled) return;

    _notificationManager.showReminderNotification(
        _globalContext!, title, message);
  }

  // Handle FCM notification
  Future<void> handleFCMNotification(RemoteMessage message) async {
    if (_globalContext == null) return;

    final data = message.data;
    final type = data['type'] ?? 'system';
    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? 'You have a new notification';

    switch (type) {
      case 'SESSION_EXPIRING':
        await showSessionExpiringNotification();
        break;
      case 'APPOINTMENT_REMINDER':
        await showAppointmentReminder(
          data['doctorName'] ?? 'Doctor',
          data['time'] ?? 'soon',
        );
        break;
      case 'SYSTEM_UPDATE':
        await showSystemUpdateNotification(data['version'] ?? '1.0.0');
        break;
      case 'ADVERTISEMENT':
        await showAdvertisementNotification(title, body);
        break;
      case 'INSTRUCTION':
        await showInstructionNotification(title, body);
        break;
      case 'GENERAL_REMINDER':
        await showReminderNotification(title, body);
        break;
      default:
        // Show as system notification
        final isEnabled =
            await _settingsService.isNotificationEnabled('system');
        if (isEnabled) {
          _notificationManager.showSystemNotification(
              _globalContext!, title, body);
        }
    }
  }
}
