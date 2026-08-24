import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_service.dart';

/// Whether this account has turned off the AI/keyword medical-document
/// check on upload (Settings > Controls > "Turn off AI file check while
/// uploading"). Meant as a fallback so a patient can still save a document
/// if the AI checker is misbehaving; the backend still always runs its
/// malware/magic-byte security checks regardless of this flag.
///
/// The account (backend) is the source of truth, so the same choice follows
/// the user across logout/login and across devices. SharedPreferences is
/// used only as a local cache for instant UI feedback and offline fallback -
/// never as the primary store.
class UploadAiCheckSettings {
  static const String _disabledKey = 'upload_ai_medical_check_disabled';

  static final UploadAiCheckSettings _instance =
      UploadAiCheckSettings._internal();
  factory UploadAiCheckSettings() => _instance;
  UploadAiCheckSettings._internal();

  final ValueNotifier<bool> disabledNotifier = ValueNotifier<bool>(false);
  bool _hydratedFromBackend = false;

  /// Returns the current value, hydrating from the backend on first call
  /// per app run. Falls back to the local cache (then the default `false`)
  /// only when the backend is unreachable.
  Future<bool> getDisabled() async {
    if (_hydratedFromBackend) return disabledNotifier.value;

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getBool(_disabledKey);
    if (cached != null) {
      disabledNotifier.value = cached;
    }

    final remote = await ApiService.fetchAiMedicalCheckDisabled();
    if (remote != null) {
      _hydratedFromBackend = true;
      disabledNotifier.value = remote;
      await prefs.setBool(_disabledKey, remote);
      return remote;
    }

    return disabledNotifier.value;
  }

  /// Sets the preference, persisting it to the account first so it's
  /// synced across devices and actually enforced by the upload endpoint.
  Future<bool> setDisabled(bool disabled) async {
    final saved = await ApiService.updateAiMedicalCheckDisabled(disabled);
    if (!saved) return false;

    disabledNotifier.value = disabled;
    _hydratedFromBackend = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_disabledKey, disabled);
    return true;
  }

  /// Clears the in-memory hydration flag so the next read re-fetches from
  /// the backend. Call this on logout/login so switching accounts on the
  /// same device never shows the previous account's cached preference.
  void resetHydration() {
    _hydratedFromBackend = false;
  }
}
