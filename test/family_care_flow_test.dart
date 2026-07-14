import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/features/family_care/data/family_care_repository.dart';
import 'package:hello/features/family_care/data/models/family_dashboard.dart';
import 'package:hello/features/family_care/data/models/patient_profile.dart';
import 'package:hello/features/family_care/providers/active_patient_profile_provider.dart';
import 'package:hello/features/family_care/providers/family_dashboard_provider.dart';
import 'package:hello/features/family_care/screens/add_family_member_screen.dart';
import 'package:hello/features/family_care/screens/family_care_dashboard_screen.dart';
import 'package:hello/providers/timezone_provider.dart';
import 'package:provider/provider.dart';

void main() {
  const profile = PatientProfile(
    id: 'profile-1',
    displayName: 'Asha Sharma',
    relationship: 'Mother',
    profileType: 'managed',
    timezone: 'Asia/Kolkata',
    dateOfBirth: '1964-06-01',
    bloodGroup: 'O+',
    allergies: ['Penicillin'],
    emergencyContact: EmergencyContact(
      name: 'Ravi Sharma',
      relationship: 'Son',
      phone: '+91 99999 99999',
    ),
  );
  const access = FamilyProfileAccess(
    profile: profile,
    role: 'owner',
    relationship: 'Mother',
    permissions: {'profileEdit': true},
  );

  test('provider completes create, detail, edit, and archive operations',
      () async {
    final repository = _FakeFamilyCareRepository(access);
    final provider = FamilyDashboardProvider(repository: repository);

    await provider.load();
    expect(provider.state, FamilyDashboardLoadState.loaded);

    final created = await provider.createManagedProfile(
      displayName: 'Neha Sharma',
      relationship: 'Daughter',
      dateOfBirth: '2010-02-01',
      timezone: 'Asia/Kolkata',
      idempotencyKey: '4f9f882b-2fa9-4c5f-a8ee-507fb39a0a16',
    );
    expect(created.profile.id, 'profile-created');
    expect(repository.createCalls, 1);

    final detail = await provider.getProfile(profile.id);
    expect(detail.profile.emergencyContact.name, 'Ravi Sharma');

    final updated = await provider.updateProfile(
      profile.id,
      {'displayName': 'Asha S. Sharma'},
    );
    expect(updated.profile.displayName, 'Asha S. Sharma');
    expect(repository.updateCalls, 1);

    await provider.archiveProfile(profile.id);
    expect(repository.archiveCalls, 1);
    expect(provider.operationState, FamilyCareOperationState.idle);
  });

  testWidgets('dashboard opens the member detail screen with permissions',
      (tester) async {
    final provider = FamilyDashboardProvider(
      repository: _FakeFamilyCareRepository(access),
    );
    await tester.pumpWidget(_app(
      provider: provider,
      child: const FamilyCareDashboardScreen(),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Asha Sharma'), findsOneWidget);
    expect(find.text('Mother'), findsOneWidget);
    await tester.tap(find.text('Asha Sharma'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Overview'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Emergency contact'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Emergency contact'), findsOneWidget);
    expect(find.byTooltip('Edit profile'), findsOneWidget);
    expect(find.byTooltip('Archive profile'), findsOneWidget);
  });

  testWidgets(
      'add form blocks incomplete or invalid profiles before any API request',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeFamilyCareRepository(access);
    await tester.pumpWidget(_app(
      provider: FamilyDashboardProvider(repository: repository),
      child: const AddFamilyMemberScreen(),
    ));

    expect(find.text('Existing Medical Vault User'), findsOneWidget);
    expect(find.text('Create Managed Family Profile'), findsOneWidget);
    await tester.tap(find.text('Create Managed Family Profile'));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Add family member'));
    await tester.pump();

    expect(find.text('This field is required.'), findsNWidgets(2));
    expect(find.text('Date of birth is required.'), findsOneWidget);
    expect(repository.createCalls, 0);

    await tester.enterText(find.byType(TextFormField).at(0), 'Neha Sharma');
    await tester.enterText(find.byType(TextFormField).at(1), 'Daughter');
    await tester.enterText(find.byType(TextFormField).at(2), '2026-02-31');
    await tester.tap(find.widgetWithText(FilledButton, 'Add family member'));
    await tester.pump();

    expect(find.text('Enter a valid date that is not in the future.'),
        findsOneWidget);
    expect(repository.createCalls, 0);
  });

  test('active profile context is cleared whenever the authenticated user changes', () {
    final active = ActivePatientProfileProvider();
    active.bindAuthenticatedUser('user-a');
    active.select(profile);
    expect(active.activeProfileId, profile.id);
    active.bindAuthenticatedUser('user-b');
    expect(active.activeProfile, isNull);
    expect(active.authenticatedUserId, 'user-b');
  });
}

Widget _app({
  required FamilyDashboardProvider provider,
  required Widget child,
}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider(create: (_) => ActivePatientProfileProvider()),
        ChangeNotifierProvider(
          create: (_) => TimezoneProvider(TimezoneProvider.defaultTimeZone),
        ),
      ],
      child: MaterialApp(home: child),
    );

class _FakeFamilyCareRepository extends FamilyCareRepository {
  _FakeFamilyCareRepository(this._access);

  FamilyProfileAccess _access;
  int createCalls = 0;
  int updateCalls = 0;
  int archiveCalls = 0;
  bool _archived = false;

  @override
  Future<FamilyDashboard> getDashboard() async => FamilyDashboard(
        date: '2026-07-14',
        timezone: 'Asia/Kolkata',
        members: _archived
            ? const []
            : [
                FamilyDashboardMember(
                  profile: _access.profile,
                  medicationState: FamilyDataState.noData,
                  medicinesScheduled: 0,
                  medicinesTaken: 0,
                  medicinesMissed: 0,
                  appointmentsToday: 0,
                  upcomingAppointments: 0,
                  recentDocuments: 0,
                ),
              ],
      );

  @override
  Future<FamilyProfileAccess> getProfile(String profileId) async => _access;

  @override
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
    createCalls += 1;
    return FamilyProfileAccess(
      profile: PatientProfile(
        id: 'profile-created',
        displayName: displayName,
        relationship: relationship,
        profileType: 'managed',
        timezone: timezone,
        dateOfBirth: dateOfBirth,
      ),
      role: 'owner',
      relationship: relationship,
      permissions: const {'profileEdit': true},
    );
  }

  @override
  Future<FamilyProfileAccess> updateProfile(
    String profileId,
    Map<String, dynamic> patch,
  ) async {
    updateCalls += 1;
    _access = FamilyProfileAccess(
      profile: PatientProfile(
        id: _access.profile.id,
        displayName:
            (patch['displayName'] ?? _access.profile.displayName).toString(),
        relationship: _access.profile.relationship,
        profileType: _access.profile.profileType,
        timezone: _access.profile.timezone,
        dateOfBirth: _access.profile.dateOfBirth,
        bloodGroup: _access.profile.bloodGroup,
        allergies: _access.profile.allergies,
        conditions: _access.profile.conditions,
        emergencyContact: _access.profile.emergencyContact,
      ),
      role: _access.role,
      relationship: _access.relationship,
      permissions: _access.permissions,
    );
    return _access;
  }

  @override
  Future<void> archiveProfile(String profileId) async {
    archiveCalls += 1;
    _archived = true;
  }
}
