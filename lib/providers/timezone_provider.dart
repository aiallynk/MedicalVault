import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTimeZoneOption {
  final String id;
  final String label;

  const AppTimeZoneOption({
    required this.id,
    required this.label,
  });
}

class TimezoneProvider extends ChangeNotifier {
  static const String storageKey = 'app_timezone';
  static const String defaultTimeZone = 'Asia/Kolkata';

  static const List<AppTimeZoneOption> supportedTimeZones = [
    AppTimeZoneOption(id: 'Asia/Kolkata', label: 'India Standard Time (IST)'),
    AppTimeZoneOption(id: 'UTC', label: 'UTC'),
    AppTimeZoneOption(id: 'Asia/Dubai', label: 'Gulf Standard Time (GST)'),
    AppTimeZoneOption(id: 'Asia/Singapore', label: 'Singapore Time (SGT)'),
    AppTimeZoneOption(id: 'Asia/Tokyo', label: 'Japan Standard Time (JST)'),
    AppTimeZoneOption(id: 'Asia/Seoul', label: 'Korea Standard Time (KST)'),
    AppTimeZoneOption(id: 'Australia/Sydney', label: 'Australian Eastern Time (AET)'),
    AppTimeZoneOption(id: 'Europe/London', label: 'UK Time (GMT/BST)'),
    AppTimeZoneOption(id: 'Europe/Paris', label: 'Central European Time (CET)'),
    AppTimeZoneOption(id: 'Europe/Berlin', label: 'Central European Time (CET)'),
    AppTimeZoneOption(id: 'Europe/Moscow', label: 'Moscow Time (MSK)'),
    AppTimeZoneOption(id: 'Africa/Johannesburg', label: 'South Africa Time (SAST)'),
    AppTimeZoneOption(id: 'America/New_York', label: 'Eastern Time (ET)'),
    AppTimeZoneOption(id: 'America/Chicago', label: 'Central Time (CT)'),
    AppTimeZoneOption(id: 'America/Denver', label: 'Mountain Time (MT)'),
    AppTimeZoneOption(id: 'America/Los_Angeles', label: 'Pacific Time (PT)'),
    AppTimeZoneOption(id: 'America/Sao_Paulo', label: 'Brasilia Time (BRT)'),
    AppTimeZoneOption(id: 'Pacific/Auckland', label: 'New Zealand Time (NZT)'),
  ];

  static final Set<String> _supportedIds =
      supportedTimeZones.map((zone) => zone.id).toSet();

  static String normalizeTimeZone(String? value) {
    final candidate = (value ?? '').toString().trim();
    if (candidate.isEmpty) return defaultTimeZone;
    return _supportedIds.contains(candidate) ? candidate : defaultTimeZone;
  }

  static Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is! Map) return null;
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }

  static String? extractTimeZoneFromUserData(Map<String, dynamic>? userData) {
    if (userData == null || userData.isEmpty) return null;

    final directPreference = userData['timezone']?.toString();
    if (_supportedIds.contains(directPreference)) {
      return directPreference;
    }

    final preferences = _asStringMap(userData['preferences']);
    final preferenceZone = preferences?['timezone']?.toString();
    if (_supportedIds.contains(preferenceZone)) {
      return preferenceZone;
    }

    final doctorPreferences = _asStringMap(userData['doctorPreferences']);
    final doctorZone = doctorPreferences?['timezone']?.toString();
    if (_supportedIds.contains(doctorZone)) {
      return doctorZone;
    }

    return null;
  }

  static Future<String> loadTimeZone() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(storageKey);
    if (_supportedIds.contains(saved)) {
      return normalizeTimeZone(saved);
    }

    final rawUserData = prefs.getString('userData');
    if (rawUserData != null && rawUserData.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawUserData);
        final userMap = _asStringMap(decoded);
        final fromUser = extractTimeZoneFromUserData(userMap);
        if (fromUser != null) {
          final normalized = normalizeTimeZone(fromUser);
          await prefs.setString(storageKey, normalized);
          return normalized;
        }
      } catch (_) {
        // Ignore malformed cache and keep fallback behavior.
      }
    }

    await prefs.setString(storageKey, defaultTimeZone);
    return defaultTimeZone;
  }

  String _timeZoneId;

  TimezoneProvider(String initialTimeZone)
      : _timeZoneId = normalizeTimeZone(initialTimeZone);

  String get timeZoneId => _timeZoneId;

  AppTimeZoneOption get selectedOption => supportedTimeZones.firstWhere(
        (zone) => zone.id == _timeZoneId,
        orElse: () => const AppTimeZoneOption(
          id: defaultTimeZone,
          label: 'India Standard Time (IST)',
        ),
      );

  Future<void> setTimeZone(String nextTimeZone) async {
    final normalized = normalizeTimeZone(nextTimeZone);
    if (normalized == _timeZoneId) return;

    _timeZoneId = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, normalized);
    notifyListeners();
  }

  Future<void> applyUserTimeZone(
    Map<String, dynamic>? userData, {
    bool fallbackToDefault = true,
  }) async {
    final fromUser = extractTimeZoneFromUserData(userData);
    final target = fromUser ?? (fallbackToDefault ? defaultTimeZone : null);
    if (target == null) return;
    await setTimeZone(target);
  }
}
