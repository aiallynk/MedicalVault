import 'package:flutter/foundation.dart';

import '../data/models/patient_profile.dart';

class ActivePatientProfileProvider extends ChangeNotifier {
  static ActivePatientProfileProvider? _instance;

  ActivePatientProfileProvider() {
    _instance = this;
  }

  PatientProfile? _activeProfile;
  String? _authenticatedUserId;
  int _selectionGeneration = 0;
  PatientProfile? get activeProfile => _activeProfile;
  String? get activeProfileId => _activeProfile?.id;
  String? get authenticatedUserId => _authenticatedUserId;
  int get selectionGeneration => _selectionGeneration;

  void bindAuthenticatedUser(String? userId) {
    final normalized = userId?.trim() ?? '';
    if (_authenticatedUserId == normalized) return;
    _authenticatedUserId = normalized.isEmpty ? null : normalized;
    _activeProfile = null;
    _selectionGeneration += 1;
    notifyListeners();
  }

  void select(PatientProfile profile) {
    if (_activeProfile?.id == profile.id) return;
    _activeProfile = profile;
    _selectionGeneration += 1;
    notifyListeners();
  }

  void clear() {
    if (_activeProfile == null) return;
    _activeProfile = null;
    _selectionGeneration += 1;
    notifyListeners();
  }

  void clearForLogout() {
    _authenticatedUserId = null;
    _activeProfile = null;
    _selectionGeneration += 1;
    notifyListeners();
  }

  static void clearGlobalSession() => _instance?.clearForLogout();
}
