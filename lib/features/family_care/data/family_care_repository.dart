import 'family_care_api.dart';
import 'models/family_dashboard.dart';
import 'models/patient_profile.dart';
import 'models/family_care_extensions.dart';

class FamilyCareRepository {
  FamilyCareRepository({FamilyCareApi? api}) : _api = api ?? FamilyCareApi();
  final FamilyCareApi _api;

  Future<List<FamilyProfileAccess>> getProfiles() async {
    final response = await _api.get('/profiles');
    final data = _map(response['data']);
    final profiles = data['profiles'];
    if (profiles is! List) return const [];
    return profiles.whereType<Map>().map((item) {
      return FamilyProfileAccess.fromJson(_map(item));
    }).toList(growable: false);
  }

  Future<FamilyDashboard> getDashboard() async {
    final response = await _api.get('/dashboard');
    return FamilyDashboard.fromJson(_map(response['data']));
  }

  Future<FamilyProfileAccess> getProfile(String profileId) async {
    final response = await _api.get('/profiles/$profileId');
    return FamilyProfileAccess.fromJson(_map(response['data']));
  }

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
    final response = await _api.post(
      '/profiles',
      body: {
        'displayName': displayName,
        'relationship': relationship,
        'dateOfBirth': dateOfBirth,
        'timezone': timezone,
        if (gender?.isNotEmpty == true) 'gender': gender,
        if (bloodGroup?.isNotEmpty == true) 'bloodGroup': bloodGroup,
        'preferredLanguage': preferredLanguage,
        'medicalSummary': {
          'allergies': allergies,
          'conditions': conditions,
        },
        if (emergencyContact != null) 'emergencyContact': emergencyContact,
      },
      idempotencyKey: idempotencyKey,
    );
    return FamilyProfileAccess.fromJson(_map(response['data']));
  }

  Future<FamilyProfileAccess> updateProfile(
    String profileId,
    Map<String, dynamic> patch,
  ) async {
    final response = await _api.patch('/profiles/$profileId', patch);
    return FamilyProfileAccess.fromJson(_map(response['data']));
  }

  Future<void> archiveProfile(String profileId) async {
    await _api.post('/profiles/$profileId/archive');
  }

  Future<List<FamilyUserSearchResult>> searchExistingUsers(String query) async {
    final response =
        await _api.get('/users/search?q=${Uri.encodeQueryComponent(query)}');
    final results = _map(response['data'])['results'];
    return results is List
        ? results
            .whereType<Map>()
            .map((item) => FamilyUserSearchResult.fromJson(_map(item)))
            .toList(growable: false)
        : const [];
  }

  Future<FamilyInvitation> requestExistingUserConnection({
    required String targetUserId,
    required String relationship,
    required String role,
    Map<String, bool> permissions = const {
      'profileRead': true,
      'profileContextSwitch': true
    },
  }) async {
    final response = await _api.post('/invitations', body: {
      'targetUserId': targetUserId,
      'relationship': relationship,
      'role': role,
      'permissions': permissions,
    });
    return FamilyInvitation.fromJson(
        _map(_map(response['data'])['invitation']));
  }

  Future<Map<String, List<FamilyInvitation>>> getInvitations() async {
    final response = await _api.get('/invitations');
    final data = _map(response['data']);
    List<FamilyInvitation> listFor(String key) => (data[key] is List)
        ? (data[key] as List)
            .whereType<Map>()
            .map((item) => FamilyInvitation.fromJson(_map(item)))
            .toList(growable: false)
        : const [];
    return {'incoming': listFor('incoming'), 'outgoing': listFor('outgoing')};
  }

  Future<void> respondToInvitation(String invitationId,
      {required bool accept}) async {
    await _api
        .post('/invitations/$invitationId/${accept ? 'accept' : 'decline'}');
  }

  Future<void> cancelInvitation(String invitationId) async {
    await _api.post('/invitations/$invitationId/cancel');
  }

  Future<Map<String, dynamic>> getConnections() async {
    final response = await _api.get('/connections');
    return _map(response['data']);
  }

  Future<void> updateConnection(
      String connectionId, Map<String, dynamic> patch) async {
    await _api.patch('/connections/$connectionId', patch);
  }

  Future<void> revokeConnection(String connectionId) async {
    await _api.delete('/connections/$connectionId');
  }

  Future<Map<String, dynamic>> getAccessControls() async {
    final response = await _api.getUser('/family-profile-access-controls');
    return _map(_map(response['data'])['controls']);
  }

  Future<Map<String, dynamic>> updateAccessControls(
      Map<String, dynamic> patch) async {
    final response =
        await _api.patchUser('/family-profile-access-controls', patch);
    return _map(_map(response['data'])['controls']);
  }

  Future<FamilyInvitation> requestProfileLink({
    required String profileId,
    required String targetUserId,
    String relationship = 'family',
  }) async {
    final response =
        await _api.post('/profiles/$profileId/link-account', body: {
      'targetUserId': targetUserId,
      'relationship': relationship,
    });
    return FamilyInvitation.fromJson(
        _map(_map(response['data'])['invitation']));
  }

  Future<void> respondToProfileLink(String linkId,
      {required bool accept}) async {
    await _api.post('/profile-links/$linkId/${accept ? 'accept' : 'decline'}');
  }

  Future<List<FamilyMedication>> getMedications(String profileId) async {
    final response = await _api.get('/profiles/$profileId/medications');
    final medications = _map(response['data'])['medications'];
    return medications is List
        ? medications
            .whereType<Map>()
            .map((item) => FamilyMedication.fromJson(_map(item)))
            .toList(growable: false)
        : const [];
  }

  Future<FamilyMedication> createMedication(
      String profileId, Map<String, dynamic> medication) async {
    final response =
        await _api.post('/profiles/$profileId/medications', body: medication);
    return FamilyMedication.fromJson(
        _map(_map(response['data'])['medication']));
  }

  Future<FamilyMedication> updateMedication(String profileId,
      String medicationId, Map<String, dynamic> medication) async {
    final response = await _api.patch(
        '/profiles/$profileId/medications/$medicationId', medication);
    return FamilyMedication.fromJson(
        _map(_map(response['data'])['medication']));
  }

  Future<List<FamilyDoctor>> getFamilyDoctors() async {
    final response = await _api.get('/doctors');
    final doctors = _map(response['data'])['doctors'];
    return doctors is List
        ? doctors
            .whereType<Map>()
            .map((item) => FamilyDoctor.fromJson(_map(item)))
            .toList(growable: false)
        : const [];
  }

  Future<List<FamilyAppointment>> getAppointments(String profileId) async {
    final response = await _api.get('/profiles/$profileId/appointments');
    final appointments = _map(response['data'])['appointments'];
    return appointments is List
        ? appointments
            .whereType<Map>()
            .map((item) => FamilyAppointment.fromJson(_map(item)))
            .toList(growable: false)
        : const [];
  }

  Future<FamilyAppointment> createAppointment(
      String profileId, Map<String, dynamic> appointment) async {
    final response =
        await _api.post('/profiles/$profileId/appointments', body: appointment);
    return FamilyAppointment.fromJson(
        _map(_map(response['data'])['appointment']));
  }

  Future<FamilyAppointment> updateAppointment(String profileId,
      String appointmentId, Map<String, dynamic> patch) async {
    final response = await _api.patch(
        '/profiles/$profileId/appointments/$appointmentId', patch);
    return FamilyAppointment.fromJson(
        _map(_map(response['data'])['appointment']));
  }

  Future<void> cancelAppointment(String profileId, String appointmentId) async {
    await _api.post('/profiles/$profileId/appointments/$appointmentId/cancel');
  }

  Future<List<MedicationDoseEvent>> getTodayDoses(String profileId) async {
    final response = await _api.get('/profiles/$profileId/doses/today');
    final doses = _map(response['data'])['doses'];
    return doses is List
        ? doses
            .whereType<Map>()
            .map((item) => MedicationDoseEvent.fromJson(_map(item)))
            .toList(growable: false)
        : const [];
  }

  Future<MedicationDoseEvent> updateDose(
    String profileId,
    String doseEventId,
    String action, {
    int? snoozeMinutes,
  }) async {
    final body = <String, dynamic>{
      if (snoozeMinutes != null) 'minutes': snoozeMinutes
    };
    final response = await _api.post(
      '/profiles/$profileId/doses/$doseEventId/$action',
      body: body,
      idempotencyKey: FamilyCareApi.newIdempotencyKey(),
    );
    return MedicationDoseEvent.fromJson(_map(_map(response['data'])['dose']));
  }

  Future<FamilyCareNotificationPreferences> getNotificationPreferences(
      {String? profileId}) async {
    final path = profileId == null
        ? '/notification-preferences'
        : '/profiles/$profileId/notification-preferences';
    final response = await _api.get(path);
    return FamilyCareNotificationPreferences.fromJson(
        _map(_map(response['data'])['preferences']));
  }

  Future<FamilyCareNotificationPreferences> updateNotificationPreferences(
      Map<String, dynamic> patch,
      {String? profileId}) async {
    final path = profileId == null
        ? '/notification-preferences'
        : '/profiles/$profileId/notification-preferences';
    final response = await _api.patch(path, patch);
    return FamilyCareNotificationPreferences.fromJson(
        _map(_map(response['data'])['preferences']));
  }
}

Map<String, dynamic> _map(dynamic value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : <String, dynamic>{};
