class PatientProfile {
  final String id;
  final String displayName;
  final String? relationship;
  final String profileType;
  final String timezone;
  final String? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final String? profilePhotoKey;
  final String status;
  final String preferredLanguage;
  final List<String> allergies;
  final List<String> conditions;
  final EmergencyContact emergencyContact;

  const PatientProfile({
    required this.id,
    required this.displayName,
    required this.profileType,
    required this.timezone,
    this.relationship,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.profilePhotoKey,
    this.status = 'active',
    this.preferredLanguage = 'en',
    this.allergies = const [],
    this.conditions = const [],
    this.emergencyContact = const EmergencyContact(),
  });

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    final summary = _map(json['medicalSummary']);
    return PatientProfile(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      displayName: (json['displayName'] ?? 'Family member').toString(),
      relationship: _optional(json['relationship']),
      profileType: (json['profileType'] ?? 'managed').toString(),
      timezone: (json['timezone'] ?? 'Asia/Kolkata').toString(),
      dateOfBirth: _optional(json['dateOfBirth']),
      gender: _optional(json['gender']),
      bloodGroup: _optional(json['bloodGroup']),
      profilePhotoKey: _optional(json['profilePhotoKey']),
      status: (json['status'] ?? 'active').toString(),
      preferredLanguage: (json['preferredLanguage'] ?? 'en').toString(),
      allergies: _stringList(summary['allergies']),
      conditions: _stringList(summary['conditions']),
      emergencyContact:
          EmergencyContact.fromJson(_map(json['emergencyContact'])),
    );
  }
}

class EmergencyContact {
  final String name;
  final String relationship;
  final String phone;

  const EmergencyContact({
    this.name = '',
    this.relationship = '',
    this.phone = '',
  });

  bool get isEmpty => name.isEmpty && relationship.isEmpty && phone.isEmpty;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        name: (json['name'] ?? '').toString(),
        relationship: (json['relationship'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
      );
}

class FamilyProfileAccess {
  final PatientProfile profile;
  final String role;
  final String relationship;
  final Map<String, bool> permissions;

  const FamilyProfileAccess({
    required this.profile,
    required this.role,
    required this.permissions,
    this.relationship = '',
  });

  factory FamilyProfileAccess.fromJson(Map<String, dynamic> json) {
    final profileJson = _map(json['profile']);
    final relationship = _map(json['relationship']);
    final rawPermissions = _map(
      relationship['permissions'] ?? profileJson['permissions'],
    );
    return FamilyProfileAccess(
      profile: PatientProfile.fromJson(profileJson),
      role:
          (relationship['role'] ?? profileJson['role'] ?? 'viewer').toString(),
      relationship:
          (relationship['relationship'] ?? profileJson['relationship'] ?? '')
              .toString(),
      permissions: rawPermissions.map(
        (key, value) => MapEntry(key, value == true),
      ),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

List<String> _stringList(dynamic value) => value is List
    ? value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false)
    : const [];

String? _optional(dynamic value) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty || result == 'null' ? null : result;
}
