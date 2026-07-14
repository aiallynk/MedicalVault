import 'package:flutter/foundation.dart';

import '../data/family_care_api.dart';
import '../data/family_care_repository.dart';
import '../data/models/family_dashboard.dart';
import '../data/models/patient_profile.dart';
import '../data/models/family_care_extensions.dart';

enum FamilyDashboardLoadState {
  initial,
  loading,
  loaded,
  empty,
  restricted,
  unavailable,
  subscriptionRequired,
  entitlementExpired,
  configurationError,
  error,
}

enum FamilyCareOperationState { idle, creating, updating, archiving }

class FamilyDashboardProvider extends ChangeNotifier {
  static FamilyDashboardProvider? _instance;

  FamilyDashboardProvider({FamilyCareRepository? repository})
      : _repository = repository ?? FamilyCareRepository() {
    _instance = this;
  }
  final FamilyCareRepository _repository;

  FamilyDashboardLoadState state = FamilyDashboardLoadState.initial;
  FamilyCareOperationState operationState = FamilyCareOperationState.idle;
  FamilyDashboard? dashboard;
  String? errorMessage;
  int _requestGeneration = 0;

  Future<void> load({bool force = false}) async {
    final generation = _requestGeneration;
    if (state == FamilyDashboardLoadState.loading) return;
    if (!force &&
        (state == FamilyDashboardLoadState.loaded ||
            state == FamilyDashboardLoadState.empty)) {
      return;
    }
    state = FamilyDashboardLoadState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final loadedDashboard = await _repository.getDashboard();
      if (generation != _requestGeneration) return;
      dashboard = loadedDashboard;
      state = dashboard!.members.isEmpty
          ? FamilyDashboardLoadState.empty
          : FamilyDashboardLoadState.loaded;
    } on FamilyCareApiException catch (error) {
      if (generation != _requestGeneration) return;
      state = _stateForApiError(error);
      errorMessage = error.message;
    } catch (_) {
      if (generation != _requestGeneration) return;
      state = FamilyDashboardLoadState.error;
      errorMessage =
          'Could not load Family Care. Check your connection and retry.';
    }
    notifyListeners();
  }

  Future<FamilyProfileAccess> getProfile(String profileId) =>
      _repository.getProfile(profileId);

  Future<List<FamilyUserSearchResult>> searchExistingUsers(String query) =>
      _repository.searchExistingUsers(query);

  Future<FamilyInvitation> requestExistingUserConnection({
    required String targetUserId,
    required String relationship,
    required String role,
  }) =>
      _repository.requestExistingUserConnection(
        targetUserId: targetUserId,
        relationship: relationship,
        role: role,
      );

  Future<List<FamilyMedication>> getMedications(String profileId) =>
      _repository.getMedications(profileId);

  Future<FamilyMedication> createMedication(
    String profileId,
    Map<String, dynamic> medication,
  ) =>
      _repository.createMedication(profileId, medication);

  Future<List<MedicationDoseEvent>> getTodayDoses(String profileId) =>
      _repository.getTodayDoses(profileId);

  Future<MedicationDoseEvent> updateDose(
    String profileId,
    String doseEventId,
    String action, {
    int? snoozeMinutes,
  }) =>
      _repository.updateDose(
        profileId,
        doseEventId,
        action,
        snoozeMinutes: snoozeMinutes,
      );

  Future<FamilyProfileAccess> createManagedProfile({
    required String displayName,
    required String relationship,
    required String dateOfBirth,
    required String timezone,
    String? gender,
    String? bloodGroup,
    List<String> allergies = const [],
    List<String> conditions = const [],
    String preferredLanguage = 'en',
    Map<String, String>? emergencyContact,
    required String idempotencyKey,
  }) async {
    operationState = FamilyCareOperationState.creating;
    notifyListeners();
    try {
      final result = await _repository.createManagedProfile(
        displayName: displayName,
        relationship: relationship,
        dateOfBirth: dateOfBirth,
        timezone: timezone,
        gender: gender,
        bloodGroup: bloodGroup,
        allergies: allergies,
        conditions: conditions,
        preferredLanguage: preferredLanguage,
        emergencyContact: emergencyContact,
        idempotencyKey: idempotencyKey,
      );
      await load(force: true);
      return result;
    } finally {
      operationState = FamilyCareOperationState.idle;
      notifyListeners();
    }
  }

  Future<FamilyProfileAccess> updateProfile(
    String profileId,
    Map<String, dynamic> patch,
  ) async {
    operationState = FamilyCareOperationState.updating;
    notifyListeners();
    try {
      final result = await _repository.updateProfile(profileId, patch);
      await load(force: true);
      return result;
    } finally {
      operationState = FamilyCareOperationState.idle;
      notifyListeners();
    }
  }

  Future<void> archiveProfile(String profileId) async {
    operationState = FamilyCareOperationState.archiving;
    notifyListeners();
    try {
      await _repository.archiveProfile(profileId);
      await load(force: true);
    } finally {
      operationState = FamilyCareOperationState.idle;
      notifyListeners();
    }
  }

  void invalidate() {
    state = FamilyDashboardLoadState.initial;
    dashboard = null;
    errorMessage = null;
    notifyListeners();
  }

  void clearSensitiveCache() {
    _requestGeneration += 1;
    state = FamilyDashboardLoadState.initial;
    operationState = FamilyCareOperationState.idle;
    dashboard = null;
    errorMessage = null;
    notifyListeners();
  }

  static void clearGlobalSession() => _instance?.clearSensitiveCache();

  FamilyDashboardLoadState _stateForApiError(FamilyCareApiException error) {
    switch (error.code) {
      case 'FAMILY_CARE_DISABLED':
        return FamilyDashboardLoadState.unavailable;
      case 'FAMILY_CARE_ENTITLEMENT_REQUIRED':
        return FamilyDashboardLoadState.subscriptionRequired;
      case 'FAMILY_CARE_ENTITLEMENT_EXPIRED':
      case 'FAMILY_CARE_ENTITLEMENT_SUSPENDED':
        return FamilyDashboardLoadState.entitlementExpired;
      case 'FAMILY_CARE_CONFIG_UNAVAILABLE':
        return FamilyDashboardLoadState.configurationError;
      default:
        return error.statusCode == 403
            ? FamilyDashboardLoadState.restricted
            : FamilyDashboardLoadState.error;
    }
  }
}
