import 'package:flutter/foundation.dart';

@immutable
class NearbyPlace {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double rating;
  final bool openNow;
  final String? phoneNumber;
  final double distanceKm;
  final String category;
  final bool openStatusKnown;
  final String? mapsUrl;

  const NearbyPlace({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.openNow,
    required this.distanceKm,
    required this.category,
    this.phoneNumber,
    this.openStatusKnown = false,
    this.mapsUrl,
  });

  factory NearbyPlace.fromJson(Map<String, dynamic> json) {
    return NearbyPlace(
      placeId: (json['placeId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      rating: _toDouble(json['rating']),
      openNow: json['openNow'] == true,
      phoneNumber: _optionalText(json['phoneNumber']),
      distanceKm: _toDouble(json['distanceKm']),
      category: (json['category'] ?? '').toString(),
      openStatusKnown: json['openStatusKnown'] == true,
      mapsUrl: _optionalText(json['mapsUrl']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'openNow': openNow,
      if (phoneNumber != null && phoneNumber!.trim().isNotEmpty)
        'phoneNumber': phoneNumber,
      'distanceKm': distanceKm,
      'category': category,
      'openStatusKnown': openStatusKnown,
      if (mapsUrl != null && mapsUrl!.trim().isNotEmpty) 'mapsUrl': mapsUrl,
    };
  }

  NearbyPlace copyWith({
    String? placeId,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? rating,
    bool? openNow,
    String? phoneNumber,
    double? distanceKm,
    String? category,
    bool? openStatusKnown,
    String? mapsUrl,
  }) {
    return NearbyPlace(
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      openNow: openNow ?? this.openNow,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      distanceKm: distanceKm ?? this.distanceKm,
      category: category ?? this.category,
      openStatusKnown: openStatusKnown ?? this.openStatusKnown,
      mapsUrl: mapsUrl ?? this.mapsUrl,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  static String? _optionalText(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }
}

enum NearbyPlaceCategory {
  all,
  hospitals,
  clinics,
  doctors,
  medicalStores,
  diagnosticLabs,
  ambulances,
}

extension NearbyPlaceCategoryDetails on NearbyPlaceCategory {
  String get cacheKey {
    return switch (this) {
      NearbyPlaceCategory.all => 'all',
      NearbyPlaceCategory.hospitals => 'hospitals',
      NearbyPlaceCategory.clinics => 'clinics',
      NearbyPlaceCategory.doctors => 'doctors',
      NearbyPlaceCategory.medicalStores => 'medical_stores',
      NearbyPlaceCategory.diagnosticLabs => 'diagnostic_labs',
      NearbyPlaceCategory.ambulances => 'ambulances',
    };
  }

  String get label {
    return switch (this) {
      NearbyPlaceCategory.all => 'All',
      NearbyPlaceCategory.hospitals => 'Hospitals',
      NearbyPlaceCategory.clinics => 'Clinics',
      NearbyPlaceCategory.doctors => 'Doctors',
      NearbyPlaceCategory.medicalStores => 'Pharmacies',
      NearbyPlaceCategory.diagnosticLabs => 'Diagnostic labs',
      NearbyPlaceCategory.ambulances => 'Ambulance / Emergency',
    };
  }

  String get singularLabel {
    return switch (this) {
      NearbyPlaceCategory.all => 'Service',
      NearbyPlaceCategory.hospitals => 'Hospital',
      NearbyPlaceCategory.clinics => 'Clinic',
      NearbyPlaceCategory.doctors => 'Doctor',
      NearbyPlaceCategory.medicalStores => 'Pharmacy',
      NearbyPlaceCategory.diagnosticLabs => 'Diagnostic lab',
      NearbyPlaceCategory.ambulances => 'Ambulance',
    };
  }

  String get serviceCategory {
    return switch (this) {
      NearbyPlaceCategory.all => 'healthcare',
      NearbyPlaceCategory.hospitals => 'hospital',
      NearbyPlaceCategory.clinics => 'clinic',
      NearbyPlaceCategory.doctors => 'doctor',
      NearbyPlaceCategory.medicalStores => 'pharmacy',
      NearbyPlaceCategory.diagnosticLabs => 'diagnostic_lab',
      NearbyPlaceCategory.ambulances => 'ambulance',
    };
  }
}
