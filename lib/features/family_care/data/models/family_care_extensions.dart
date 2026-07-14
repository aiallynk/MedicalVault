class FamilyUserSearchResult {
  const FamilyUserSearchResult({
    required this.id,
    required this.displayName,
    this.maskedEmail = '',
    this.maskedPhone = '',
  });

  final String id;
  final String displayName;
  final String maskedEmail;
  final String maskedPhone;

  factory FamilyUserSearchResult.fromJson(Map<String, dynamic> json) =>
      FamilyUserSearchResult(
        id: (json['id'] ?? '').toString(),
        displayName: (json['displayName'] ?? 'Medical Vault member').toString(),
        maskedEmail: (json['maskedEmail'] ?? '').toString(),
        maskedPhone: (json['maskedPhone'] ?? '').toString(),
      );
}

class FamilyInvitation {
  const FamilyInvitation({
    required this.id,
    required this.kind,
    required this.status,
    this.relationship = '',
    this.role = 'viewer',
  });

  final String id;
  final String kind;
  final String status;
  final String relationship;
  final String role;

  factory FamilyInvitation.fromJson(Map<String, dynamic> json) =>
      FamilyInvitation(
        id: (json['id'] ?? '').toString(),
        kind: (json['kind'] ?? 'connection').toString(),
        status: (json['status'] ?? 'pending').toString(),
        relationship: (json['intendedRelationship'] ?? '').toString(),
        role: (json['intendedRole'] ?? 'viewer').toString(),
      );
}

class MedicationSchedule {
  const MedicationSchedule({
    required this.id,
    required this.scheduleType,
    required this.localTimes,
    required this.timezone,
    this.weekdays = const [],
    this.intervalHours,
  });

  final String id;
  final String scheduleType;
  final List<String> localTimes;
  final List<int> weekdays;
  final int? intervalHours;
  final String timezone;

  factory MedicationSchedule.fromJson(Map<String, dynamic> json) =>
      MedicationSchedule(
        id: (json['id'] ?? '').toString(),
        scheduleType: (json['scheduleType'] ?? 'once_daily').toString(),
        localTimes: _strings(json['localTimes']),
        weekdays: _ints(json['weekdays']),
        intervalHours: int.tryParse((json['intervalHours'] ?? '').toString()),
        timezone: (json['timezone'] ?? 'Asia/Kolkata').toString(),
      );
}

class FamilyMedication {
  const FamilyMedication({
    required this.id,
    required this.name,
    required this.doseQuantity,
    required this.doseUnit,
    required this.status,
    this.strength = '',
    this.dosageForm = '',
    this.foodInstruction = 'not_specified',
    this.schedule,
  });

  final String id;
  final String name;
  final String strength;
  final String dosageForm;
  final num doseQuantity;
  final String doseUnit;
  final String foodInstruction;
  final String status;
  final MedicationSchedule? schedule;

  factory FamilyMedication.fromJson(Map<String, dynamic> json) =>
      FamilyMedication(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? 'Medicine').toString(),
        strength: (json['strength'] ?? '').toString(),
        dosageForm: (json['dosageForm'] ?? '').toString(),
        doseQuantity: (json['doseQuantity'] is num)
            ? json['doseQuantity'] as num
            : num.tryParse((json['doseQuantity'] ?? '0').toString()) ?? 0,
        doseUnit: (json['doseUnit'] ?? '').toString(),
        foodInstruction:
            (json['foodInstruction'] ?? 'not_specified').toString(),
        status: (json['status'] ?? 'active').toString(),
        schedule: json['schedule'] is Map
            ? MedicationSchedule.fromJson(_map(json['schedule']))
            : null,
      );
}

class MedicationDoseEvent {
  const MedicationDoseEvent({
    required this.id,
    required this.medicationOrderId,
    required this.status,
    required this.originalLocalTime,
    required this.scheduleTimezone,
    this.medicationName,
  });

  final String id;
  final String medicationOrderId;
  final String status;
  final String originalLocalTime;
  final String scheduleTimezone;
  final String? medicationName;

  factory MedicationDoseEvent.fromJson(Map<String, dynamic> json) =>
      MedicationDoseEvent(
        id: (json['id'] ?? '').toString(),
        medicationOrderId: (json['medicationOrderId'] ?? '').toString(),
        status: (json['status'] ?? 'pending').toString(),
        originalLocalTime: (json['originalLocalTime'] ?? '').toString(),
        scheduleTimezone:
            (json['scheduleTimezone'] ?? 'Asia/Kolkata').toString(),
        medicationName: json['medicationName']?.toString(),
      );
}

class FamilyDoctor {
  const FamilyDoctor(
      {required this.id,
      required this.name,
      this.specialization = '',
      this.location = ''});
  final String id;
  final String name;
  final String specialization;
  final String location;
  factory FamilyDoctor.fromJson(Map<String, dynamic> json) => FamilyDoctor(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? 'Doctor').toString(),
        specialization: (json['specialization'] ?? '').toString(),
        location: (json['location'] ?? '').toString(),
      );
}

class FamilyAppointment {
  const FamilyAppointment({
    required this.id,
    required this.date,
    required this.time,
    required this.reason,
    required this.status,
    required this.doctor,
    this.appointmentType = 'consultation',
    this.mode = 'in-person',
    this.notes = '',
  });
  final String id;
  final String date;
  final String time;
  final String reason;
  final String status;
  final FamilyDoctor doctor;
  final String appointmentType;
  final String mode;
  final String notes;
  factory FamilyAppointment.fromJson(Map<String, dynamic> json) =>
      FamilyAppointment(
        id: (json['id'] ?? '').toString(),
        date: (json['appointmentDate'] ?? '').toString(),
        time: (json['appointmentTime'] ?? '').toString(),
        reason: (json['reason'] ?? '').toString(),
        status: (json['status'] ?? 'pending').toString(),
        doctor: FamilyDoctor.fromJson(_map(json['doctor'])),
        appointmentType: (json['appointmentType'] ?? 'consultation').toString(),
        mode: (json['mode'] ?? 'in-person').toString(),
        notes: (json['notes'] ?? '').toString(),
      );
}

class FamilyCareNotificationPreferences {
  const FamilyCareNotificationPreferences({
    required this.enabled,
    required this.medicineDue,
    required this.repeatReminder,
    required this.medicineMissed,
    required this.caregiverMissedDoseAlert,
    required this.takenConfirmation,
    required this.skippedConfirmation,
    required this.refillReminder,
    required this.lowStockReminder,
    required this.quietHours,
  });

  final bool enabled;
  final bool medicineDue;
  final bool repeatReminder;
  final bool medicineMissed;
  final bool caregiverMissedDoseAlert;
  final bool takenConfirmation;
  final bool skippedConfirmation;
  final bool refillReminder;
  final bool lowStockReminder;
  final FamilyCareQuietHours quietHours;

  factory FamilyCareNotificationPreferences.fromJson(
          Map<String, dynamic> json) =>
      FamilyCareNotificationPreferences(
        enabled: json['enabled'] != false,
        medicineDue: json['medicineDue'] != false,
        repeatReminder: json['repeatReminder'] != false,
        medicineMissed: json['medicineMissed'] != false,
        caregiverMissedDoseAlert: json['caregiverMissedDoseAlert'] != false,
        takenConfirmation: json['takenConfirmation'] == true,
        skippedConfirmation: json['skippedConfirmation'] == true,
        refillReminder: json['refillReminder'] != false,
        lowStockReminder: json['lowStockReminder'] != false,
        quietHours: FamilyCareQuietHours.fromJson(_map(json['quietHours'])),
      );
}

class FamilyCareQuietHours {
  const FamilyCareQuietHours({
    required this.enabled,
    required this.start,
    required this.end,
    required this.timezone,
  });

  final bool enabled;
  final String start;
  final String end;
  final String timezone;

  factory FamilyCareQuietHours.fromJson(Map<String, dynamic> json) =>
      FamilyCareQuietHours(
        enabled: json['enabled'] == true,
        start: (json['start'] ?? '22:00').toString(),
        end: (json['end'] ?? '07:00').toString(),
        timezone: (json['timezone'] ?? 'Asia/Kolkata').toString(),
      );
}

Map<String, dynamic> _map(dynamic value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : <String, dynamic>{};

List<String> _strings(dynamic value) => value is List
    ? value.map((item) => item.toString()).toList(growable: false)
    : const [];

List<int> _ints(dynamic value) => value is List
    ? value
        .map((item) => int.tryParse(item.toString()))
        .whereType<int>()
        .toList(growable: false)
    : const [];
