import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class NotificationSettingsService {
  static const String _sessionExpiringKey = 'notification_session_expiring';
  static const String _remindersKey = 'notification_reminders';
  static const String _systemKey = 'notification_system';
  static const String _familyCareKey = 'notification_family_care';

  // Singleton pattern
  static final NotificationSettingsService _instance =
      NotificationSettingsService._internal();
  factory NotificationSettingsService() => _instance;
  NotificationSettingsService._internal();

  // Get notification settings
  Future<Map<String, bool>> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'sessionExpiring': prefs.getBool(_sessionExpiringKey) ?? true,
      'reminders': prefs.getBool(_remindersKey) ?? true,
      'system': prefs.getBool(_systemKey) ?? true,
      'familyCare': prefs.getBool(_familyCareKey) ?? true,
    };
  }

  // Update notification setting
  Future<void> updateNotificationSetting(String type, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    String key;

    switch (type) {
      case 'sessionExpiring':
        key = _sessionExpiringKey;
        break;
      case 'reminders':
        key = _remindersKey;
        break;
      case 'system':
        key = _systemKey;
        break;
      case 'familyCare':
        key = _familyCareKey;
        break;
      default:
        throw ArgumentError('Invalid notification type: $type');
    }

    await prefs.setBool(key, enabled);

    if (kDebugMode) {
      print('Updated $type notification setting to: $enabled');
    }
  }

  // Check if specific notification type is enabled
  Future<bool> isNotificationEnabled(String type) async {
    final settings = await getNotificationSettings();
    return settings[type] ?? true;
  }

  // Get all settings as a map for easy access
  Future<Map<String, bool>> getAllSettings() async {
    return await getNotificationSettings();
  }
}
