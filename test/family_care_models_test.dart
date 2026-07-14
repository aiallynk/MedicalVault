import 'package:flutter_test/flutter_test.dart';
import 'package:hello/features/family_care/data/models/family_dashboard.dart';
import 'package:hello/features/family_care/data/models/patient_profile.dart';
import 'package:hello/features/family_care/providers/active_patient_profile_provider.dart';

void main() {
  test('patient profile parses subject identity separately from login user',
      () {
    final profile = PatientProfile.fromJson({
      '_id': 'profile-1',
      'displayName': 'Mother',
      'profileType': 'managed',
      'timezone': 'Asia/Kolkata',
    });
    expect(profile.id, 'profile-1');
    expect(profile.displayName, 'Mother');
    expect(profile.profileType, 'managed');
  });

  test('dashboard preserves explicit no-data medication state', () {
    final dashboard = FamilyDashboard.fromJson({
      'date': '2026-07-10',
      'timezone': 'Asia/Kolkata',
      'profiles': [
        {
          'profile': {'_id': 'p1', 'displayName': 'Father'},
          'medicationStatus': {'state': 'no_data'},
          'appointments': {'today': [], 'upcoming': []},
          'recentDocuments': [],
        }
      ],
    });
    expect(dashboard.members.single.medicationState, FamilyDataState.noData);
  });

  test('active patient provider switches health subject without auth changes',
      () {
    final provider = ActivePatientProfileProvider();
    const profile = PatientProfile(
        id: 'p1',
        displayName: 'Child',
        profileType: 'managed',
        timezone: 'Asia/Kolkata');
    provider.select(profile);
    expect(provider.activeProfileId, 'p1');
    provider.clear();
    expect(provider.activeProfile, isNull);
  });
}
