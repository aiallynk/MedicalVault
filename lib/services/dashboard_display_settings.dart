import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_service.dart';

/// User-configurable toggles for optional dashboard sections.
///
/// The account (backend) is the source of truth, so the same choice follows
/// the user across logout/login and across devices. SharedPreferences is
/// used only as a local cache for instant UI feedback and offline fallback -
/// never as the primary store.
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
  bool _hydratedFromBackend = false;

  /// Returns the current value, hydrating from the backend on first call
  /// per app run. Falls back to the local cache (then the default `true`)
  /// only when the backend is unreachable, so the toggle still works
  /// offline but never treats the local cache as authoritative once the
  /// network is available.
  Future<bool> getShowTopDoctors() async {
    if (_hydratedFromBackend) return showTopDoctorsNotifier.value;

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getBool(_showTopDoctorsKey);
    if (cached != null) {
      showTopDoctorsNotifier.value = cached;
    }

    final remote = await ApiService.fetchShowTopDoctorsPreference();
    if (remote != null) {
      _hydratedFromBackend = true;
      showTopDoctorsNotifier.value = remote;
      await prefs.setBool(_showTopDoctorsKey, remote);
      return remote;
    }

    // Backend unreachable (offline): use the local cache/default for this
    // session, but do not mark as hydrated so the next call retries the
    // backend rather than permanently trusting a possibly-stale local value.
    return showTopDoctorsNotifier.value;
  }

  /// Sets the preference, persisting it to the account first so it's
  /// synced across devices; the local cache is updated as a fallback for
  /// the next offline read.
  Future<void> setShowTopDoctors(bool enabled) async {
    showTopDoctorsNotifier.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showTopDoctorsKey, enabled);

    final saved = await ApiService.updateShowTopDoctorsPreference(enabled);
    if (saved) {
      _hydratedFromBackend = true;
    }
    // If the save failed (offline), _hydratedFromBackend stays false so the
    // next getShowTopDoctors() call retries against the backend instead of
    // silently keeping a value that was never actually persisted server-side.
  }

  /// Clears the in-memory hydration flag so the next read re-fetches from
  /// the backend. Call this on logout/login so switching accounts on the
  /// same device never shows the previous account's cached preference.
  void resetHydration() {
    _hydratedFromBackend = false;
  }
}
