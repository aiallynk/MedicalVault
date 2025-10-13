import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_settings_service.dart';

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final NotificationSettingsService _settingsService =
      NotificationSettingsService();

  // Show session expiring notification
  Future<void> showSessionExpiringNotification(BuildContext context) async {
    final isEnabled =
        await _settingsService.isNotificationEnabled('sessionExpiring');
    if (!isEnabled) return;

    if (kDebugMode) {
      print('Showing session expiring notification');
    }

    // Show in-app notification
    _showInAppNotification(
      context,
      'Session Expiring',
      'Your session with the doctor will expire in 15 seconds. Please save your work.',
      Icons.timer,
      Colors.orange,
    );
  }

  // Show reminder notification
  Future<void> showReminderNotification(
      BuildContext context, String title, String message) async {
    final isEnabled = await _settingsService.isNotificationEnabled('reminders');
    if (!isEnabled) return;

    if (kDebugMode) {
      print('Showing reminder notification: $title');
    }

    _showInAppNotification(
      context,
      title,
      message,
      Icons.notifications,
      Colors.blue,
    );
  }

  // Show system notification
  Future<void> showSystemNotification(
      BuildContext context, String title, String message) async {
    final isEnabled = await _settingsService.isNotificationEnabled('system');
    if (!isEnabled) return;

    if (kDebugMode) {
      print('Showing system notification: $title');
    }

    _showInAppNotification(
      context,
      title,
      message,
      Icons.info,
      Colors.green,
    );
  }

  // Show appointment reminder
  Future<void> showAppointmentReminder(
      BuildContext context, String doctorName, String time) async {
    await showReminderNotification(
      context,
      'Appointment Reminder',
      'You have an appointment with Dr. $doctorName at $time',
    );
  }

  // Show system update notification
  Future<void> showSystemUpdateNotification(
      BuildContext context, String version) async {
    await showSystemNotification(
      context,
      'System Update',
      'HealthVault has been updated to version $version. New features available!',
    );
  }

  // Show advertisement notification
  Future<void> showAdvertisementNotification(
      BuildContext context, String title, String message) async {
    await showSystemNotification(context, title, message);
  }

  // Show instruction notification
  Future<void> showInstructionNotification(
      BuildContext context, String title, String message) async {
    await showSystemNotification(context, title, message);
  }

  // Private method to show in-app notification
  void _showInAppNotification(
    BuildContext context,
    String title,
    String message,
    IconData icon,
    Color color,
  ) {
    // Show a snackbar with notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // Handle FCM message based on type
  Future<void> handleFCMNotification(
      BuildContext context, RemoteMessage message) async {
    final data = message.data;
    final type = data['type'] ?? 'system';
    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? 'You have a new notification';

    switch (type) {
      case 'SESSION_EXPIRING':
        await showSessionExpiringNotification(context);
        break;
      case 'APPOINTMENT_REMINDER':
        await showAppointmentReminder(
            context, data['doctorName'] ?? 'Doctor', data['time'] ?? 'soon');
        break;
      case 'SYSTEM_UPDATE':
        await showSystemUpdateNotification(context, data['version'] ?? '1.0.0');
        break;
      case 'ADVERTISEMENT':
        await showAdvertisementNotification(context, title, body);
        break;
      case 'INSTRUCTION':
        await showInstructionNotification(context, title, body);
        break;
      case 'GENERAL_REMINDER':
        await showReminderNotification(context, title, body);
        break;
      default:
        await showSystemNotification(context, title, body);
    }
  }
}
