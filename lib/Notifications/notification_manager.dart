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
    if (!context.mounted) return;

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

  // Show session expiring notification with doctor name
  Future<void> showSessionExpiringNotificationWithDoctor(
      BuildContext context, String doctorName) async {
    final isEnabled =
        await _settingsService.isNotificationEnabled('sessionExpiring');
    if (!isEnabled) return;
    if (!context.mounted) return;

    if (kDebugMode) {
      print('Showing session expiring notification for Dr. $doctorName');
    }

    // Show in-app notification
    _showInAppNotification(
      context,
      'Session Expiring',
      'Your session with Dr. $doctorName is expiring in 30 seconds',
      Icons.timer,
      Colors.orange,
    );
  }

  // Show reminder notification
  Future<void> showReminderNotification(
    BuildContext context,
    String title,
    String message, {
    VoidCallback? onTap,
  }) async {
    final isEnabled = await _settingsService.isNotificationEnabled('reminders');
    if (!isEnabled) return;
    if (!context.mounted) return;

    if (kDebugMode) {
      print('Showing reminder notification: $title');
    }

    _showInAppNotification(
      context,
      title,
      message,
      Icons.notifications,
      Colors.blue,
      onTap: onTap,
    );
  }

  // Show system notification
  Future<void> showSystemNotification(
    BuildContext context,
    String title,
    String message, {
    VoidCallback? onTap,
  }) async {
    final isEnabled = await _settingsService.isNotificationEnabled('system');
    if (!isEnabled) return;
    if (!context.mounted) return;

    if (kDebugMode) {
      print('Showing system notification: $title');
    }

    _showInAppNotification(
      context,
      title,
      message,
      Icons.info,
      Colors.green,
      onTap: onTap,
    );
  }

  // Show appointment reminder
  Future<void> showAppointmentReminder(
    BuildContext context,
    String doctorName,
    String time, {
    VoidCallback? onTap,
  }) async {
    await showReminderNotification(
      context,
      'Appointment Reminder',
      'You have an appointment with Dr. $doctorName at $time',
      onTap: onTap,
    );
  }

  // Show system update notification
  Future<void> showSystemUpdateNotification(
    BuildContext context,
    String version, {
    VoidCallback? onTap,
  }) async {
    await showSystemNotification(
      context,
      'System Update',
      'HealthVault has been updated to version $version. New features available!',
      onTap: onTap,
    );
  }

  // Show advertisement notification
  Future<void> showAdvertisementNotification(
    BuildContext context,
    String title,
    String message, {
    VoidCallback? onTap,
  }) async {
    await showSystemNotification(context, title, message, onTap: onTap);
  }

  // Show instruction notification
  Future<void> showInstructionNotification(
    BuildContext context,
    String title,
    String message, {
    VoidCallback? onTap,
  }) async {
    await showSystemNotification(context, title, message, onTap: onTap);
  }

  // Private method to show in-app notification
  void _showInAppNotification(BuildContext context, String title,
      String message, IconData icon, Color color,
      {VoidCallback? onTap}) {
    final messenger = ScaffoldMessenger.of(context);
    final isActionable = onTap != null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.94),
                color.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.24),
                ),
                child: Icon(icon, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      message,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        action: SnackBarAction(
          label: isActionable ? 'Open' : 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            messenger.hideCurrentSnackBar();
            if (isActionable) {
              onTap();
            }
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
