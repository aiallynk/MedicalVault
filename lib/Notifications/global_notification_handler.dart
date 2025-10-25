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
    print('🔔 GlobalNotificationHandler.handleFCMNotification called');
    print('  - Global context: ${_globalContext != null ? "Set" : "Not set"}');
    print('  - Message ID: ${message.messageId}');
    print('  - Title: ${message.notification?.title}');
    print('  - Body: ${message.notification?.body}');
    print('  - Data: ${message.data}');

    if (_globalContext == null) {
      print('❌ Global context not set, cannot show notification');
      return;
    }

    final data = message.data;
    final type = data['type'] ?? 'system';
    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? 'You have a new notification';

    print('📱 Handling FCM notification: $type - $title');

    switch (type) {
      case 'SESSION_REQUEST':
        await _handleSessionRequest(data, title, body);
        break;
      case 'SESSION_RESPONSE':
        await _handleSessionResponse(data, title, body);
        break;
      case 'APPOINTMENT_SCHEDULED':
        await _handleAppointmentScheduled(data, title, body);
        break;
      case 'APPOINTMENT_UPDATED':
        await _handleAppointmentUpdated(data, title, body);
        break;
      case 'APPOINTMENT_CANCELLED':
        await _handleAppointmentCancelled(data, title, body);
        break;
      case 'APPOINTMENT_REMINDER':
        await _handleAppointmentReminder(data, title, body);
        break;
      case 'FILE_UPLOAD':
        await _handleFileUpload(data, title, body);
        break;
      case 'MEDICATION_REMINDER':
        await _handleMedicationReminder(data, title, body);
        break;
      case 'SYSTEM_NOTIFICATION':
        await _handleSystemNotification(data, title, body);
        break;
      case 'SESSION_EXPIRING':
        await showSessionExpiringNotification();
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

  // Handle session request notification
  Future<void> _handleSessionRequest(
      Map<String, dynamic> data, String title, String body) async {
    print('🔔 Handling session request notification');
    final isEnabled =
        await _settingsService.isNotificationEnabled('sessionExpiring');
    print('  - Session notifications enabled: $isEnabled');
    if (!isEnabled) return;

    _notificationManager.showSystemNotification(_globalContext!, title, body);
    print('✅ Session request notification shown');
  }

  // Handle session response notification
  Future<void> _handleSessionResponse(
      Map<String, dynamic> data, String title, String body) async {
    final isEnabled =
        await _settingsService.isNotificationEnabled('sessionExpiring');
    if (!isEnabled) return;

    _notificationManager.showSystemNotification(_globalContext!, title, body);
  }

  // Handle appointment scheduled notification
  Future<void> _handleAppointmentScheduled(
      Map<String, dynamic> data, String title, String body) async {
    final isEnabled = await _settingsService.isNotificationEnabled('reminders');
    if (!isEnabled) return;

    _notificationManager.showSystemNotification(_globalContext!, title, body);
  }

  // Handle appointment updated notification
  Future<void> _handleAppointmentUpdated(
      Map<String, dynamic> data, String title, String body) async {
    final isEnabled = await _settingsService.isNotificationEnabled('reminders');
    if (!isEnabled) return;

    _notificationManager.showSystemNotification(_globalContext!, title, body);
  }

  // Handle appointment cancelled notification
  Future<void> _handleAppointmentCancelled(
      Map<String, dynamic> data, String title, String body) async {
    final isEnabled = await _settingsService.isNotificationEnabled('reminders');
    if (!isEnabled) return;

    _notificationManager.showSystemNotification(_globalContext!, title, body);
  }

  // Handle appointment reminder notification
  Future<void> _handleAppointmentReminder(
      Map<String, dynamic> data, String title, String body) async {
    final isEnabled = await _settingsService.isNotificationEnabled('reminders');
    if (!isEnabled) return;

    _notificationManager.showSystemNotification(_globalContext!, title, body);
  }

  // Handle file upload notification
  Future<void> _handleFileUpload(
      Map<String, dynamic> data, String title, String body) async {
    final isEnabled = await _settingsService.isNotificationEnabled('system');
    if (!isEnabled) return;

    _notificationManager.showSystemNotification(_globalContext!, title, body);
  }

  // Handle medication reminder notification
  Future<void> _handleMedicationReminder(
      Map<String, dynamic> data, String title, String body) async {
    final isEnabled = await _settingsService.isNotificationEnabled('reminders');
    if (!isEnabled) return;

    _notificationManager.showSystemNotification(_globalContext!, title, body);
  }

  // Handle system notification
  Future<void> _handleSystemNotification(
      Map<String, dynamic> data, String title, String body) async {
    final isEnabled = await _settingsService.isNotificationEnabled('system');
    if (!isEnabled) return;

    _notificationManager.showSystemNotification(_globalContext!, title, body);
  }
}
