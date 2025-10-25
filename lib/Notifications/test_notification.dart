import 'package:flutter/material.dart';
import 'package:hello/Notifications/global_notification_handler.dart';
import 'package:hello/Notifications/notification_manager.dart';
import 'package:hello/Notifications/notification_settings_service.dart';

class TestNotificationScreen extends StatefulWidget {
  const TestNotificationScreen({super.key});

  @override
  State<TestNotificationScreen> createState() => _TestNotificationScreenState();
}

class _TestNotificationScreenState extends State<TestNotificationScreen> {
  final NotificationManager _notificationManager = NotificationManager();
  final NotificationSettingsService _settingsService =
      NotificationSettingsService();
  final GlobalNotificationHandler _globalHandler = GlobalNotificationHandler();

  @override
  void initState() {
    super.initState();
    // Set global context for this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalNotificationHandler.setGlobalContext(context);
    });
  }

  Future<void> _testSystemNotification() async {
    await _notificationManager.showSystemNotification(
      context,
      'Test System Notification',
      'This is a test system notification to verify the system is working',
    );
  }

  Future<void> _testReminderNotification() async {
    await _notificationManager.showReminderNotification(
      context,
      'Test Reminder',
      'This is a test reminder notification',
    );
  }

  Future<void> _testSessionNotification() async {
    await _notificationManager.showSessionExpiringNotification(context);
  }

  Future<void> _testAppointmentNotification() async {
    await _notificationManager.showAppointmentReminder(
      context,
      'Dr. Test Doctor',
      '10:00 AM',
    );
  }

  Future<void> _checkNotificationSettings() async {
    final systemEnabled =
        await _settingsService.isNotificationEnabled('system');
    final remindersEnabled =
        await _settingsService.isNotificationEnabled('reminders');
    final sessionEnabled =
        await _settingsService.isNotificationEnabled('sessionExpiring');

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Notification Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'System Notifications: ${systemEnabled ? "Enabled" : "Disabled"}'),
              Text(
                  'Reminder Notifications: ${remindersEnabled ? "Enabled" : "Disabled"}'),
              Text(
                  'Session Notifications: ${sessionEnabled ? "Enabled" : "Disabled"}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Notifications'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test In-App Notifications',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _testSystemNotification,
              child: const Text('Test System Notification'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _testReminderNotification,
              child: const Text('Test Reminder Notification'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _testSessionNotification,
              child: const Text('Test Session Notification'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _testAppointmentNotification,
              child: const Text('Test Appointment Notification'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkNotificationSettings,
              child: const Text('Check Notification Settings'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Instructions:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Tap each button to test different notification types\n'
              '2. Check if notifications appear as SnackBars\n'
              '3. Verify notification settings are enabled\n'
              '4. If notifications don\'t appear, check console logs',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
