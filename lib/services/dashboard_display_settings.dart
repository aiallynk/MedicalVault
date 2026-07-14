import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-configurable toggles for optional dashboard sections.
///
/// Exposes a [ValueNotifier] so any already-mounted dashboard instance
/// reflects a change immediately, without needing to be recreated or
/// re-read the preference on its own schedule.
class DashboardDisplaySettings {
  static const String _showTopDoctorsKey = 'dashboard_show_top_doctors';

  static final DashboardDisplaySettings _instance =
      DashboardDisplaySettings._internal();
  factory DashboardDisplaySettings() => _instance;
  DashboardDisplaySettings._internal();

  final ValueNotifier<bool> showTopDoctorsNotifier = ValueNotifier<bool>(true);
  bool _hydrated = false;

  Future<bool> getShowTopDoctors() async {
    if (_hydrated) return showTopDoctorsNotifier.value;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_showTopDoctorsKey) ?? true;
    _hydrated = true;
    showTopDoctorsNotifier.value = value;
    return value;
  }

  Future<void> setShowTopDoctors(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showTopDoctorsKey, enabled);
    _hydrated = true;
    showTopDoctorsNotifier.value = enabled;
  }
}
