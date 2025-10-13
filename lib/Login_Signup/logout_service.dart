import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class LogoutService {
  static final LogoutService _instance = LogoutService._internal();
  factory LogoutService() => _instance;
  LogoutService._internal();

  // Clear all user session data
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear all authentication-related data
      await prefs.remove('token');
      await prefs.remove('authToken');
      await prefs.remove('userData');
      await prefs.remove('userId');
      await prefs.remove('privacy_accepted');
      await prefs.remove('privacy_accepted_date');
      await prefs.remove('privacy_version');

      // Clear notification settings if needed
      await prefs.remove('notification_session_expiring');
      await prefs.remove('notification_reminders');
      await prefs.remove('notification_system');

      if (kDebugMode) {
        print('User logged out successfully - all session data cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during logout: $e');
      }
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final authToken = prefs.getString('authToken');
      return (token != null || authToken != null);
    } catch (e) {
      if (kDebugMode) {
        print('Error checking login status: $e');
      }
      return false;
    }
  }
}
