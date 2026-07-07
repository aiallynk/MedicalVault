import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import '../models/nearby_place.dart';
import 'offline/offline_storage_service.dart';

class NearbyPlacesException implements Exception {
  const NearbyPlacesException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class NearbyPlacesService {
  NearbyPlacesService({
    http.Client? client,
    OfflineStorageService? storage,
    String? apiKey,
  })  : _client = client ?? http.Client(),
        _storage = storage ?? OfflineStorageService.instance,
        _apiKey = (apiKey ?? AppEnvironment.googleMapsApiKey).trim();

  static const Duration cacheDuration = Duration(minutes: 15);
  static const Duration _requestTimeout = Duration(seconds: 12);
  static const double _cacheLocationToleranceMeters = 750;
  static const String _nearbyEndpoint =
      'https://places.googleapis.com/v1/places:searchNearby';
  static const String _textEndpoint =
      'https://places.googleapis.com/v1/places:searchText';
  static const String _placesFieldMask =
      'places.id,places.displayName,places.formattedAddress,'
      'places.location,places.rating,places.currentOpeningHours,'
      'places.internationalPhoneNumber,places.nationalPhoneNumber,'
      'places.googleMapsUri,places.types';

  final http.Client _client;
  final OfflineStorageService _storage;
  final String _apiKey;

  bool lastResultFromCache = false;
  bool lastResultWasStale = false;
  String lastStatusMessage = '';

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
      request: (resolvedOrigin, resolvedRadius) => _searchNearbyByTypes(
        category: NearbyPlaceCategory.hospitals,
        origin: resolvedOrigin,
        radiusMeters: resolvedRadius,
        includedTypes: const ['hospital'],
      ),
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
      request: (resolvedOrigin, resolvedRadius) => _searchTextPlaces(
        category: NearbyPlaceCategory.clinics,
        origin: resolvedOrigin,
        radiusMeters: resolvedRadius,
        textQuery: 'clinic',
      ),
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
      request: (resolvedOrigin, resolvedRadius) => _searchNearbyByTypes(
        category: NearbyPlaceCategory.medicalStores,
        origin: resolvedOrigin,
        radiusMeters: resolvedRadius,
        includedTypes: const ['pharmacy'],
      ),
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
      request: (resolvedOrigin, resolvedRadius) async {
        final results = <NearbyPlace>[];
        for (final query in const [
          'ambulance',
          'emergency service',
          'ambulance provider',
        ]) {
          results.addAll(
            await _searchTextPlaces(
              category: NearbyPlaceCategory.ambulances,
              origin: resolvedOrigin,
              radiusMeters: resolvedRadius,
              textQuery: query,
            ),
          );
        }

        final dedupedAmbulances = _dedupeAndSort(results);
        if (dedupedAmbulances.isNotEmpty) return dedupedAmbulances;

        return _searchTextPlaces(
          category: NearbyPlaceCategory.ambulances,
          origin: resolvedOrigin,
          radiusMeters: resolvedRadius,
          textQuery: 'emergency hospital',
          includedType: 'hospital',
        );
      },
    );
  }

  Future<List<NearbyPlace>> _getWithCache({
    required NearbyPlaceCategory category,
    required Position? origin,
    required double radiusMeters,
    required bool forceRefresh,
    required Future<List<NearbyPlace>> Function(Position origin, double radius)
        request,
  }) async {
    lastResultFromCache = false;
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

    if (_apiKey.isEmpty) {
      if (staleCache != null) {
        lastResultFromCache = true;
        lastResultWasStale = true;
        lastStatusMessage =
            'Showing cached results. Google Maps API key is not configured.';
        return staleCache;
      }
      throw const NearbyPlacesException(
        'Google Maps API key is not configured.',
        code: 'missing_api_key',
      );
    }

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

    try {
      final places =
          _dedupeAndSort(await request(resolvedOrigin, resolvedRadius));
      await _cachePlaces(
        category: category,
        origin: resolvedOrigin,
        radiusMeters: resolvedRadius,
        places: places,
      );
      return places;
    } catch (error) {
      if (staleCache != null) {
        lastResultFromCache = true;
        lastResultWasStale = true;
        lastStatusMessage = 'Showing cached results. Live discovery failed.';
        return staleCache;
      }
      if (error is NearbyPlacesException) rethrow;
      throw NearbyPlacesException(
        'Unable to load nearby ${category.label.toLowerCase()}.',
        code: 'places_request_failed',
      );
    }
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

  Future<List<NearbyPlace>> _searchNearbyByTypes({
    required NearbyPlaceCategory category,
    required Position origin,
    required double radiusMeters,
    required List<String> includedTypes,
  }) async {
    final body = {
      'includedTypes': includedTypes,
      'maxResultCount': 20,
      'rankPreference': 'DISTANCE',
      'locationRestriction': _circlePayload(origin, radiusMeters),
    };

    final decoded = await _postPlacesJson(
      endpoint: _nearbyEndpoint,
      fieldMask: _placesFieldMask,
      body: body,
    );

    return _mapPlaces(decoded['places'], category, origin);
  }

  Future<List<NearbyPlace>> _searchTextPlaces({
    required NearbyPlaceCategory category,
    required Position origin,
    required double radiusMeters,
    required String textQuery,
    String? includedType,
  }) async {
    final body = {
      'textQuery': textQuery,
      'maxResultCount': 20,
      'rankPreference': 'DISTANCE',
      'locationBias': _circlePayload(origin, radiusMeters),
      if (includedType != null && includedType.trim().isNotEmpty)
        'includedType': includedType.trim(),
    };

    final decoded = await _postPlacesJson(
      endpoint: _textEndpoint,
      fieldMask: _placesFieldMask,
      body: body,
    );

    return _mapPlaces(decoded['places'], category, origin);
  }

  Map<String, dynamic> _circlePayload(Position origin, double radiusMeters) {
    return {
      'circle': {
        'center': {
          'latitude': origin.latitude,
          'longitude': origin.longitude,
        },
        'radius': radiusMeters,
      },
    };
  }

  Future<Map<String, dynamic>> _postPlacesJson({
    required String endpoint,
    required String fieldMask,
    required Map<String, dynamic> body,
  }) async {
    final response = await _client
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask': fieldMask,
          },
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);

    final decoded = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      final message = error is Map
          ? (error['message'] ?? 'Google Places request failed').toString()
          : 'Google Places request failed (${response.statusCode}).';
      throw NearbyPlacesException(message, code: 'api_failure');
    }

    return decoded;
  }

  Map<String, dynamic> _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      // Fall through to an empty map.
    }
    return <String, dynamic>{};
  }

  List<NearbyPlace> _mapPlaces(
    dynamic rawPlaces,
    NearbyPlaceCategory category,
    Position origin,
  ) {
    if (rawPlaces is! List) return const <NearbyPlace>[];
    final mapped = <NearbyPlace>[];

    for (final raw in rawPlaces) {
      if (raw is! Map) continue;
      final place = raw.map((key, value) => MapEntry(key.toString(), value));
      final location = place['location'];
      final locationMap = location is Map
          ? location.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};

      final latitude = _toDouble(locationMap['latitude']);
      final longitude = _toDouble(locationMap['longitude']);
      if (latitude == 0 || longitude == 0) continue;

      final id = (place['id'] ?? '').toString().trim();
      final displayName = place['displayName'];
      final name = displayName is Map
          ? (displayName['text'] ?? '').toString().trim()
          : '';
      if (id.isEmpty || name.isEmpty) continue;

      final openingHours = place['currentOpeningHours'];
      final openingHoursMap = openingHours is Map
          ? openingHours.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      final openNowKnown = openingHoursMap.containsKey('openNow');
      final openNow = openingHoursMap['openNow'] == true;
      final distanceKm = Geolocator.distanceBetween(
            origin.latitude,
            origin.longitude,
            latitude,
            longitude,
          ) /
          1000;

      mapped.add(
        NearbyPlace(
          placeId: id,
          name: name,
          address: (place['formattedAddress'] ?? '').toString(),
          latitude: latitude,
          longitude: longitude,
          rating: _toDouble(place['rating']),
          openNow: openNow,
          openStatusKnown: openNowKnown,
          phoneNumber: _firstText(
            place['internationalPhoneNumber'],
            place['nationalPhoneNumber'],
          ),
          distanceKm: double.parse(distanceKm.toStringAsFixed(2)),
          category: category.serviceCategory,
          mapsUrl: _firstText(place['googleMapsUri']),
        ),
      );
    }

    return _dedupeAndSort(mapped);
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
}
