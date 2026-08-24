import 'patient_profile.dart';

enum FamilyDataState {
  complete,
  needsAttention,
  upcoming,
  noData,
  restricted,
  failed
}

class FamilyDashboardMember {
  final PatientProfile profile;
  final FamilyDataState medicationState;
  final int medicinesScheduled;
  final int medicinesTaken;
  final int medicinesMissed;
  final int appointmentsToday;
  final int upcomingAppointments;
  final int recentDocuments;

  const FamilyDashboardMember({
    required this.profile,
    required this.medicationState,
    required this.medicinesScheduled,
    required this.medicinesTaken,
    required this.medicinesMissed,
    required this.appointmentsToday,
    required this.upcomingAppointments,
    required this.recentDocuments,
  });

  factory FamilyDashboardMember.fromJson(Map<String, dynamic> json) {
    final medication = _map(json['medicationStatus']);
    final appointments = _map(json['appointments']);
    final state = switch ((medication['state'] ?? '').toString()) {
      'complete' => FamilyDataState.complete,
      'needs_attention' || 'attention' => FamilyDataState.needsAttention,
      'upcoming' || 'scheduled' => FamilyDataState.upcoming,
      'restricted' => FamilyDataState.restricted,
      'failed' => FamilyDataState.failed,
      _ => FamilyDataState.noData,
    };
    return FamilyDashboardMember(
      profile: PatientProfile.fromJson(_map(json['profile'])),
      medicationState: state,
      medicinesScheduled: _integer(medication['scheduled']),
      medicinesTaken: _integer(medication['taken']),
      medicinesMissed: _integer(medication['missed']),
      appointmentsToday: _list(appointments['today']).length,
      upcomingAppointments: _list(appointments['upcoming']).length,
      recentDocuments: _list(json['recentDocuments']).length,
    );
  }
}

class FamilyDashboard {
  final String date;
  final String timezone;
  final List<FamilyDashboardMember> members;
  final int? managedProfileCount;
  final int? managedProfileLimit;

  const FamilyDashboard({
    required this.date,
    required this.timezone,
    required this.members,
    this.managedProfileCount,
    this.managedProfileLimit,
  });

  bool get canCreateManagedProfile =>
      managedProfileLimit == null || managedProfileCount == null
          ? true
          : managedProfileCount! < managedProfileLimit!;

  factory FamilyDashboard.fromJson(Map<String, dynamic> json) {
    final managedProfiles = _map(json['managedProfiles']);
    return FamilyDashboard(
      date: (json['date'] ?? '').toString(),
      timezone: (json['timezone'] ?? 'Asia/Kolkata').toString(),
      members: _list(json['profiles'])
          .whereType<Map>()
          .map((item) => FamilyDashboardMember.fromJson(_map(item)))
          .toList(growable: false),
      managedProfileCount: managedProfiles.containsKey('used')
          ? _integer(managedProfiles['used'])
          : null,
      managedProfileLimit: managedProfiles.containsKey('limit')
          ? _integer(managedProfiles['limit'])
          : null,
    );
  }
}

Map<String, dynamic> _map(dynamic value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : <String, dynamic>{};
List<dynamic> _list(dynamic value) => value is List ? value : const [];
int _integer(dynamic value) =>
    value is int ? value : int.tryParse('$value') ?? 0;
