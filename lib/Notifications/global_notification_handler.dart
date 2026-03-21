import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_manager.dart';
import 'notification_settings_service.dart';
import '../BottomNavigationBar/Requests.dart';
import '../screens/appointments_page.dart';
import '../screens/appointment_detail_screen.dart';
import '../screens/direct_chat_screen.dart';
import '../screens/chat_threads_screen.dart';

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
  Future<void> showSystemUpdateNotification(
    String version, {
    VoidCallback? onTap,
  }) async {
    if (_globalContext == null) return;

    final isEnabled = await _settingsService.isNotificationEnabled('system');
    if (!isEnabled) return;

    _notificationManager.showSystemUpdateNotification(
      _globalContext!,
      version,
      onTap: onTap,
    );
  }

  // Show advertisement notification
  Future<void> showAdvertisementNotification(
    String title,
    String message, {
    VoidCallback? onTap,
  }) async {
    if (_globalContext == null) return;

    final isEnabled = await _settingsService.isNotificationEnabled('system');
    if (!isEnabled) return;

    _notificationManager.showAdvertisementNotification(
      _globalContext!,
      title,
      message,
      onTap: onTap,
    );
  }

  // Show instruction notification
  Future<void> showInstructionNotification(
    String title,
    String message, {
    VoidCallback? onTap,
  }) async {
    if (_globalContext == null) return;

    final isEnabled = await _settingsService.isNotificationEnabled('system');
    if (!isEnabled) return;

    _notificationManager.showInstructionNotification(
      _globalContext!,
      title,
      message,
      onTap: onTap,
    );
  }

  // Show general reminder notification
  Future<void> showReminderNotification(
    String title,
    String message, {
    VoidCallback? onTap,
  }) async {
    if (_globalContext == null) return;

    final isEnabled = await _settingsService.isNotificationEnabled('reminders');
    if (!isEnabled) return;

    _notificationManager.showReminderNotification(
      _globalContext!,
      title,
      message,
      onTap: onTap,
    );
  }

  /// Handle notification tap - navigate to appointment detail when applicable
  Future<void> handleNotificationTap(RemoteMessage message) async {
    final data = message.data;
    final type = data['type']?.toString() ?? '';
    final action = _buildNavigationAction(data, type);
    if (action != null) {
      action();
    }
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
    final onTap = _buildNavigationAction(data, type.toString());

    print('📱 Handling FCM notification: $type - $title');

    switch (type) {
      case 'SESSION_REQUEST':
        await _handleSessionRequest(data, title, body, onTap: onTap);
        break;
      case 'SESSION_RESPONSE':
        await _handleSessionResponse(data, title, body, onTap: onTap);
        break;
      case 'SESSION_EXTENSION_REQUEST':
      case 'SESSION_EXTENSION_RESPONSE':
        await _handleSessionResponse(data, title, body, onTap: onTap);
        break;
      case 'DIRECT_MESSAGE':
      case 'PATIENT_MESSAGE':
      case 'DOCTOR_MESSAGE':
        await _handleSystemNotification(data, title, body, onTap: onTap);
        break;
      case 'APPOINTMENT_SCHEDULED':
        await _handleAppointmentScheduled(data, title, body, onTap: onTap);
        break;
      case 'APPOINTMENT_UPDATED':
        await _handleAppointmentUpdated(data, title, body, onTap: onTap);
        break;
      case 'APPOINTMENT_CANCELLED':
        await _handleAppointmentCancelled(data, title, body, onTap: onTap);
        break;
      case 'APPOINTMENT_REMINDER':
      case 'APPOINTMENT_24H_REMINDER':
      case 'APPOINTMENT_1H_REMINDER':
      case 'APPOINTMENT_BOOKED':
      case 'APPOINTMENT_APPROVED':
      case 'APPOINTMENT_RESCHEDULED':
      case 'APPOINTMENT_COMPLETED':
      case 'DOCTOR_RUNNING_LATE':
        await _handleAppointmentReminder(data, title, body, onTap: onTap);
        break;
      case 'FILE_UPLOAD':
        await _handleFileUpload(data, title, body, onTap: onTap);
        break;
      case 'MEDICATION_REMINDER':
        await _handleMedicationReminder(data, title, body, onTap: onTap);
        break;
      case 'SYSTEM_NOTIFICATION':
        await _handleSystemNotification(data, title, body, onTap: onTap);
        break;
      case 'SESSION_EXPIRING':
        await showSessionExpiringNotification();
        break;
      case 'SYSTEM_UPDATE':
        await showSystemUpdateNotification(
          data['version'] ?? '1.0.0',
          onTap: onTap,
        );
        break;
      case 'ADVERTISEMENT':
        await showAdvertisementNotification(title, body, onTap: onTap);
        break;
      case 'INSTRUCTION':
        await showInstructionNotification(title, body, onTap: onTap);
        break;
      case 'GENERAL_REMINDER':
        await showReminderNotification(title, body, onTap: onTap);
        break;
      default:
        // Show as system notification
        final isEnabled =
            await _settingsService.isNotificationEnabled('system');
        if (isEnabled) {
          _notificationManager.showSystemNotification(
            _globalContext!,
            title,
            body,
            onTap: onTap,
          );
        }
    }
  }

  // Handle session request notification
  Future<void> _handleSessionRequest(
    Map<String, dynamic> data,
    String title,
    String body, {
    VoidCallback? onTap,
  }) async {
    print('🔔 Handling session request notification');
    final isEnabled =
        await _settingsService.isNotificationEnabled('sessionExpiring');
    print('  - Session notifications enabled: $isEnabled');
    if (!isEnabled) return;

    _notificationManager.showSystemNotification(
      _globalContext!,
      title,
      body,
      onTap: onTap,
    );
    print('✅ Session request notification shown');
  }

  // Handle session response notification
  Future<void> _handleSessionResponse(
    Map<String, dynamic> data,
    String title,
    String body, {
    VoidCallback? onTap,
  }) async {
    final isEnabled =
        await _settingsService.isNotificationEnabled('sessionExpiring');
    if (!isEnabled) return;

    _notificationManager.showSystemNotification(
      _globalContext!,
      title,
      body,
      onTap: onTap,
    );
  }

  // Handle appointment scheduled notification
  Future<void> _handleAppointmentScheduled(
    Map<String, dynamic> data,
    String title,
    String body, {
    VoidCallback? onTap,
  }) async {
    final isEnabled = await _settingsService.isNotificationEnabled('reminders');
    if (!isEnabled) return;

    _notificationManager.showSystemNotification(
      _globalContext!,
      title,
      body,
      onTap: onTap,
    );
  }

  // Handle appointment updated notification
  Future<void> _handleAppointmentUpdated(
    Map<String, dynamic> data,
    String title,
    String body, {
    VoidCallback? onTap,
  }) async {
    final isEnabled = await _settingsService.isNotificationEnabled('reminders');
    if (!isEnabled) return;

    _notificationManager.showSystemNotification(
      _globalContext!,
      title,
      body,
      onTap: onTap,
    );
  }

  // Handle appointment cancelled notification
  Future<void> _handleAppointmentCancelled(
    Map<String, dynamic> data,
    String title,
    String body, {
    VoidCallback? onTap,
  }) async {
    final isEnabled = await _settingsService.isNotificationEnabled('reminders');
    if (!isEnabled) return;

    _notificationManager.showSystemNotification(
      _globalContext!,
      title,
      body,
      onTap: onTap,
    );
  }

  // Handle appointment reminder notification
  Future<void> _handleAppointmentReminder(
    Map<String, dynamic> data,
    String title,
    String body, {
    VoidCallback? onTap,
  }) async {
    final isEnabled = await _settingsService.isNotificationEnabled('reminders');
    if (!isEnabled) return;

    _notificationManager.showSystemNotification(
      _globalContext!,
      title,
      body,
      onTap: onTap,
    );
  }

  // Handle file upload notification
  Future<void> _handleFileUpload(
    Map<String, dynamic> data,
    String title,
    String body, {
    VoidCallback? onTap,
  }) async {
    final isEnabled = await _settingsService.isNotificationEnabled('system');
    if (!isEnabled) return;

    _notificationManager.showSystemNotification(
      _globalContext!,
      title,
      body,
      onTap: onTap,
    );
  }

  // Handle medication reminder notification
  Future<void> _handleMedicationReminder(
    Map<String, dynamic> data,
    String title,
    String body, {
    VoidCallback? onTap,
  }) async {
    final isEnabled = await _settingsService.isNotificationEnabled('reminders');
    if (!isEnabled) return;

    _notificationManager.showSystemNotification(
      _globalContext!,
      title,
      body,
      onTap: onTap,
    );
  }

  // Handle system notification
  Future<void> _handleSystemNotification(
    Map<String, dynamic> data,
    String title,
    String body, {
    VoidCallback? onTap,
  }) async {
    final isEnabled = await _settingsService.isNotificationEnabled('system');
    if (!isEnabled) return;

    _notificationManager.showSystemNotification(
      _globalContext!,
      title,
      body,
      onTap: onTap,
    );
  }

  VoidCallback? _buildNavigationAction(
    Map<String, dynamic> data,
    String type,
  ) {
    if (_globalContext == null || !_globalContext!.mounted) return null;
    final normalizedType = type.trim().toUpperCase();
    final appointmentId = data['appointmentId']?.toString().trim() ?? '';
    if (appointmentId.isNotEmpty &&
        (normalizedType.startsWith('APPOINTMENT_') ||
            normalizedType == 'DOCTOR_RUNNING_LATE')) {
      return () => _openAppointmentDetail(appointmentId);
    }

    final deepLink = data['deepLink']?.toString().trim() ?? '';
    if (deepLink.contains('/appointments')) {
      return _openAppointments;
    }
    if (deepLink.contains('/requests') ||
        normalizedType.startsWith('SESSION_')) {
      return _openRequests;
    }

    if (normalizedType == 'DIRECT_MESSAGE' ||
        normalizedType == 'PATIENT_MESSAGE' ||
        normalizedType == 'DOCTOR_MESSAGE') {
      final counterpartId = data['senderId']?.toString().trim() ??
          data['counterpartId']?.toString().trim() ??
          '';
      final counterpartName = data['senderName']?.toString().trim() ?? '';
      final counterpartAvatar = data['senderAvatar']?.toString().trim() ??
          data['counterpartAvatar']?.toString().trim() ??
          '';
      final sessionId = data['sessionId']?.toString().trim() ?? '';
      return () => _openMessages(
            counterpartId: counterpartId,
            counterpartName: counterpartName,
            counterpartAvatarUrl: counterpartAvatar,
            sessionId: sessionId,
          );
    }

    if (normalizedType == 'FILE_UPLOAD') {
      return _openAppointments;
    }

    return null;
  }

  void _openAppointmentDetail(String appointmentId) {
    if (_globalContext == null || !_globalContext!.mounted) return;
    Navigator.of(_globalContext!).push(
      MaterialPageRoute(
        builder: (context) => AppointmentDetailScreen(
          appointmentId: appointmentId,
        ),
      ),
    );
  }

  void _openAppointments() {
    if (_globalContext == null || !_globalContext!.mounted) return;
    Navigator.of(_globalContext!).push(
      MaterialPageRoute(
        builder: (context) => const AppointmentsPage(initialTab: 0),
      ),
    );
  }

  void _openRequests() {
    if (_globalContext == null || !_globalContext!.mounted) return;
    Navigator.of(_globalContext!).push(
      MaterialPageRoute(
        builder: (context) => RequestsPage(),
      ),
    );
  }

  void _openMessages({
    String counterpartId = '',
    String counterpartName = '',
    String counterpartAvatarUrl = '',
    String sessionId = '',
  }) {
    if (_globalContext == null || !_globalContext!.mounted) return;
    final normalizedCounterpartId = counterpartId.trim();
    if (normalizedCounterpartId.isEmpty) {
      Navigator.of(_globalContext!).push(
        MaterialPageRoute(
          builder: (context) => const ChatThreadsScreen(),
        ),
      );
      return;
    }

    Navigator.of(_globalContext!).push(
      MaterialPageRoute(
        builder: (context) => DirectChatScreen(
          counterpartId: normalizedCounterpartId,
          counterpartName:
              counterpartName.isEmpty ? 'Conversation' : counterpartName,
          // Flutter app is patient-side. Direct-chat counterpart is doctor.
          counterpartRole: 'doctor',
          counterpartAvatarUrl: counterpartAvatarUrl,
          sessionId: sessionId.isEmpty ? null : sessionId,
        ),
      ),
    );
  }
}
