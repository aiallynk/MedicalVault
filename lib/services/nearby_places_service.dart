import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../api_service.dart';
import '../config/app_environment.dart';
import '../models/nearby_place.dart';
import 'google_places_service.dart';
import 'offline/offline_storage_service.dart';

class NearbyPlacesException implements Exception {
  const NearbyPlacesException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Nearby healthcare lookup.
///
/// The app calls Google Places directly on-device (via [GooglePlacesService])
/// using the app's own `GOOGLE_MAPS_API_KEY` as the primary path: current
/// location -> Google Places request -> local parsing/distance/sort. If the
/// device has no Google Maps key configured, or the direct call fails, the
/// backend (`GET /api/nearby/services`) is used as a secondary source, and a
/// stale local cache is used as a last resort so the screen is never empty
/// purely because Google Places failed.
class NearbyPlacesService {
  NearbyPlacesService({
    OfflineStorageService? storage,
    GooglePlacesService? googlePlaces,
  })  : _storage = storage ?? OfflineStorageService.instance,
        _googlePlaces = googlePlaces ?? const GooglePlacesService();

  static const Duration cacheDuration = Duration(minutes: 15);
  static const double _cacheLocationToleranceMeters = 750;

  final OfflineStorageService _storage;
  final GooglePlacesService _googlePlaces;

  bool lastResultFromCache = false;
  bool lastResultFromBackend = false;
  bool lastResultFromGoogle = false;
  bool lastResultWasStale = false;
  String lastStatusMessage = '';

  Future<List<NearbyPlace>> getNearbyAll({
    Position? origin,
    double radiusMeters = 10000,
    bool forceRefresh = false,
  }) {
    return _getWithCache(
      category: NearbyPlaceCategory.all,
      origin: origin,
      radiusMeters: radiusMeters,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<NearbyPlace>> getNearbyHospitals({
    Position? origin,
    double radiusMeters = 10000,
    bool forceRefresh = false,
  }) {
    return _getWithCache(
      category: NearbyPlaceCategory.hospitals,
      origin: origin,
      radiusMeters: radiusMeters,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<NearbyPlace>> getNearbyClinics({
    Position? origin,
    double radiusMeters = 10000,
    bool forceRefresh = false,
  }) {
    return _getWithCache(
      category: NearbyPlaceCategory.clinics,
      origin: origin,
      radiusMeters: radiusMeters,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<NearbyPlace>> getNearbyDoctors({
    Position? origin,
    double radiusMeters = 10000,
    bool forceRefresh = false,
  }) {
    return _getWithCache(
      category: NearbyPlaceCategory.doctors,
      origin: origin,
      radiusMeters: radiusMeters,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<NearbyPlace>> getNearbyMedicalStores({
    Position? origin,
    double radiusMeters = 10000,
    bool forceRefresh = false,
  }) {
    return _getWithCache(
      category: NearbyPlaceCategory.medicalStores,
      origin: origin,
      radiusMeters: radiusMeters,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<NearbyPlace>> getNearbyDiagnosticLabs({
    Position? origin,
    double radiusMeters = 10000,
    bool forceRefresh = false,
  }) {
    return _getWithCache(
      category: NearbyPlaceCategory.diagnosticLabs,
      origin: origin,
      radiusMeters: radiusMeters,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<NearbyPlace>> getNearbyAmbulances({
    Position? origin,
    double radiusMeters = 10000,
    bool forceRefresh = false,
  }) {
    return _getWithCache(
      category: NearbyPlaceCategory.ambulances,
      origin: origin,
      radiusMeters: radiusMeters,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<NearbyPlace>> _getWithCache({
    required NearbyPlaceCategory category,
    required Position? origin,
    required double radiusMeters,
    required bool forceRefresh,
  }) async {
    lastResultFromCache = false;
    lastResultFromBackend = false;
    lastResultFromGoogle = false;
    lastResultWasStale = false;
    lastStatusMessage = '';

    final resolvedOrigin = await _resolveOrigin(origin);
    final resolvedRadius = radiusMeters.clamp(500, 50000).toDouble();

    if (!forceRefresh) {
      final fresh = await _readCachedPlaces(
        category: category,
        origin: resolvedOrigin,
        radiusMeters: resolvedRadius,
        allowStale: false,
      );
      if (fresh != null) {
        lastResultFromCache = true;
        return fresh;
      }
    }

    final staleCache = await _readCachedPlaces(
      category: category,
      origin: resolvedOrigin,
      radiusMeters: resolvedRadius,
      allowStale: true,
    );

    if (!await _hasNetworkConnection()) {
      if (staleCache != null) {
        lastResultFromCache = true;
        lastResultWasStale = true;
        lastStatusMessage = 'Showing cached results. No internet connection.';
        return staleCache;
      }
      throw const NearbyPlacesException(
        'No internet connection. Check your network and try again.',
        code: 'no_internet',
      );
    }

    // Primary path: call Google Places directly from the device.
    if (AppEnvironment.hasGoogleMapsApiKey) {
      try {
        final places = await _googlePlaces.searchNearby(
          category: category,
          origin: resolvedOrigin,
          radiusMeters: resolvedRadius,
        );
        lastResultFromGoogle = true;
        if (places.isNotEmpty) {
          await _cachePlaces(
            category: category,
            origin: resolvedOrigin,
            radiusMeters: resolvedRadius,
            places: places,
          );
          return places;
        }
        // Zero results from Google: fall through to the backend, which may
        // have internal directory/fallback data for this area.
      } catch (_) {
        // Direct Google Places call failed (network, key restriction, quota,
        // etc.) — fall through to the backend as a secondary source.
      }
    }

    Map<String, dynamic> backend;
    try {
      backend = await ApiService.fetchNearbyServices(
        latitude: resolvedOrigin.latitude,
        longitude: resolvedOrigin.longitude,
        radiusKm: resolvedRadius / 1000,
        types: _backendTypesForCategory(category),
      );
    } catch (_) {
      if (staleCache != null) {
        lastResultFromCache = true;
        lastResultWasStale = true;
        lastStatusMessage = 'Showing cached results. Live lookup failed.';
        return staleCache;
      }
      throw NearbyPlacesException(
        'Unable to load nearby ${category.label.toLowerCase()}.',
        code: 'backend_unreachable',
      );
    }

    if (backend['success'] == true) {
      final places = _mapBackendPlaces(
        backend['services'],
        category,
        resolvedOrigin,
      );
      lastResultFromBackend = true;
      lastResultFromCache = backend['isCached'] == true;
      lastResultWasStale = backend['isStale'] == true;
      lastStatusMessage = (backend['message'] ?? '').toString().trim();

      if (!lastResultFromCache) {
        await _cachePlaces(
          category: category,
          origin: resolvedOrigin,
          radiusMeters: resolvedRadius,
          places: places,
        );
      }
      return places;
    }

    // Backend returned a degraded response (e.g. REQUEST_DENIED, missing key).
    final message = (backend['message'] ?? '').toString().trim();
    final code = (backend['code'] ?? '').toString().trim();

    if (staleCache != null) {
      lastResultFromCache = true;
      lastResultWasStale = true;
      lastStatusMessage =
          message.isNotEmpty ? message : 'Showing cached results.';
      return staleCache;
    }

    throw NearbyPlacesException(
      message.isNotEmpty ? message : 'Nearby lookup is currently unavailable.',
      code: code.isNotEmpty ? code : 'backend_error',
    );
  }

  Future<Position> _resolveOrigin(Position? origin) async {
    if (origin != null) return origin;
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) return lastKnown;
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 8),
    );
  }

  List<NearbyPlace> _dedupeAndSort(List<NearbyPlace> places) {
    final byId = <String, NearbyPlace>{};
    for (final place in places) {
      final key = place.placeId.trim().isNotEmpty
          ? place.placeId
          : '${place.category}:${place.name}:${place.latitude}:${place.longitude}';
      final existing = byId[key];
      if (existing == null) {
        byId[key] = place;
        continue;
      }
      if ((existing.phoneNumber == null || existing.phoneNumber!.isEmpty) &&
          (place.phoneNumber?.isNotEmpty ?? false)) {
        byId[key] = place;
      }
    }
    return byId.values.toList(growable: false)
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  }

  Future<List<NearbyPlace>?> _readCachedPlaces({
    required NearbyPlaceCategory category,
    required Position origin,
    required double radiusMeters,
    required bool allowStale,
  }) async {
    final payload = await _storage.getCachedNearbyPlaces(category.cacheKey);
    if (payload == null) return null;

    final fetchedAt =
        DateTime.tryParse((payload['fetchedAt'] ?? '').toString());
    if (fetchedAt == null) return null;
    final isStale =
        DateTime.now().difference(fetchedAt.toLocal()) > cacheDuration;
    if (isStale && !allowStale) return null;

    final cachedRadius = _toDouble(payload['radiusMeters']);
    if ((cachedRadius - radiusMeters).abs() > 1) return null;

    final cachedLatitude = _toDouble(payload['originLatitude']);
    final cachedLongitude = _toDouble(payload['originLongitude']);
    if (cachedLatitude == 0 || cachedLongitude == 0) return null;
    final originDistance = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      cachedLatitude,
      cachedLongitude,
    );
    if (originDistance > _cacheLocationToleranceMeters) return null;

    final rawPlaces = payload['places'];
    if (rawPlaces is! List) return const <NearbyPlace>[];
    final places = rawPlaces
        .whereType<Map>()
        .map(
          (entry) => NearbyPlace.fromJson(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);

    return _dedupeAndSort(places);
  }

  Future<void> _cachePlaces({
    required NearbyPlaceCategory category,
    required Position origin,
    required double radiusMeters,
    required List<NearbyPlace> places,
  }) {
    return _storage.cacheNearbyPlaces(
      cacheKey: category.cacheKey,
      payload: {
        'category': category.cacheKey,
        'originLatitude': origin.latitude,
        'originLongitude': origin.longitude,
        'radiusMeters': radiusMeters,
        'fetchedAt': DateTime.now().toUtc().toIso8601String(),
        'places': places.map((place) => place.toJson()).toList(growable: false),
      },
    );
  }

  Future<bool> _hasNetworkConnection() async {
    final dynamic result = await Connectivity().checkConnectivity();
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    if (result is List<ConnectivityResult>) {
      return result.any((entry) => entry != ConnectivityResult.none);
    }
    if (result is Iterable) {
      return result.any((entry) => entry != ConnectivityResult.none);
    }
    return true;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  static String? _firstText(Object? first, [Object? second]) {
    final firstText = (first ?? '').toString().trim();
    if (firstText.isNotEmpty) return firstText;
    final secondText = (second ?? '').toString().trim();
    return secondText.isEmpty ? null : secondText;
  }

  List<String> _backendTypesForCategory(NearbyPlaceCategory category) {
    return switch (category) {
      NearbyPlaceCategory.all => const [
          'hospital',
          'clinic',
          'doctor',
          'pharmacy',
          'diagnostic_lab',
          'ambulance',
        ],
      NearbyPlaceCategory.hospitals => const ['hospital'],
      NearbyPlaceCategory.clinics => const ['clinic'],
      NearbyPlaceCategory.doctors => const ['doctor'],
      NearbyPlaceCategory.medicalStores => const ['pharmacy'],
      NearbyPlaceCategory.diagnosticLabs => const ['diagnostic_lab'],
      NearbyPlaceCategory.ambulances => const ['ambulance'],
    };
  }

  List<NearbyPlace> _mapBackendPlaces(
    dynamic rawServices,
    NearbyPlaceCategory category,
    Position origin,
  ) {
    if (rawServices is! List) return const <NearbyPlace>[];

    final mapped = <NearbyPlace>[];
    for (final raw in rawServices) {
      if (raw is! Map) continue;
      final service = raw.map((key, value) => MapEntry(key.toString(), value));

      final latitude = _toDouble(service['latitude'] ?? service['lat']);
      final longitude = _toDouble(service['longitude'] ?? service['lng']);
      // Skip contacts without coordinates (e.g. emergency phone entries); the
      // page shows those in its dedicated emergency section instead.
      if (latitude == 0 || longitude == 0) continue;

      final name = (service['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final placeId =
          (service['placeId'] ?? service['id'] ?? '').toString().trim();
      final availability = (service['availability'] ?? '').toString().trim();
      final openNow = service['openNow'] == true ||
          availability.toUpperCase() == 'OPEN_NOW';
      final openStatusKnown = service.containsKey('openNow') ||
          availability.toUpperCase() != 'UNKNOWN';
      final distanceKmValue = _toDouble(service['distanceKm']);
      final resolvedDistanceKm = distanceKmValue > 0
          ? distanceKmValue
          : Geolocator.distanceBetween(
                  origin.latitude, origin.longitude, latitude, longitude) /
              1000;

      mapped.add(
        NearbyPlace(
          placeId: placeId.isNotEmpty
              ? placeId
              : 'backend_${category.cacheKey}_${latitude.toStringAsFixed(6)}_${longitude.toStringAsFixed(6)}',
          name: name,
          address: (service['address'] ?? '').toString(),
          latitude: latitude,
          longitude: longitude,
          rating: _toDouble(service['rating']),
          openNow: openNow,
          openStatusKnown: openStatusKnown,
          phoneNumber: _firstText(service['phone'], service['phoneNumber']),
          distanceKm: double.parse(resolvedDistanceKm.toStringAsFixed(2)),
          category: _firstText(service['type']) ?? category.serviceCategory,
          mapsUrl: (service['mapsUrl'] ?? '').toString().trim().isNotEmpty
              ? service['mapsUrl'].toString()
              : _buildMapsSearchUrl(
                  latitude: latitude,
                  longitude: longitude,
                  placeId: placeId,
                ),
        ),
      );
    }

    return _dedupeAndSort(mapped);
  }

  String _buildMapsSearchUrl({
    required double latitude,
    required double longitude,
    required String placeId,
  }) {
    final query =
        '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
      if (placeId.trim().isNotEmpty) 'query_place_id': placeId.trim(),
    });
    return uri.toString();
  }
}
