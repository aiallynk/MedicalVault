import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import '../models/nearby_place.dart';

class GooglePlacesException implements Exception {
  const GooglePlacesException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Calls Google Places (Legacy Nearby Search / Text Search) directly from the
/// device using the app's own `GOOGLE_MAPS_API_KEY` (read via
/// [AppEnvironment]). Results are parsed locally, distance is computed
/// on-device with [Geolocator.distanceBetween], and the list is sorted
/// nearest-first before being handed back as [NearbyPlace] models.
class GooglePlacesService {
  const GooglePlacesService();

  static const String _nearbySearchUrl =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
  static const String _textSearchUrl =
      'https://maps.googleapis.com/maps/api/place/textsearch/json';
  static const Duration _timeout = Duration(seconds: 8);

  Future<List<NearbyPlace>> searchNearby({
    required NearbyPlaceCategory category,
    required Position origin,
    required double radiusMeters,
  }) async {
    final apiKey = AppEnvironment.googleMapsApiKey;
    if (apiKey.isEmpty) {
      throw const GooglePlacesException(
        'Google Maps API key is not configured on this device.',
        code: 'missing_api_key',
      );
    }

    final strategy = _strategyForCategory(category);
    final clampedRadius = radiusMeters.clamp(500, 50000).toDouble();

    final uri = strategy.usesTextSearch
        ? Uri.parse(_textSearchUrl).replace(queryParameters: {
            'query': strategy.textQuery!,
            'location': '${origin.latitude},${origin.longitude}',
            'radius': clampedRadius.round().toString(),
            'key': apiKey,
          })
        : Uri.parse(_nearbySearchUrl).replace(queryParameters: {
            'location': '${origin.latitude},${origin.longitude}',
            'radius': clampedRadius.round().toString(),
            'type': strategy.placeType!,
            'key': apiKey,
          });

    http.Response response;
    try {
      response = await http.get(uri).timeout(_timeout);
    } catch (error) {
      throw GooglePlacesException(
        'Unable to reach Google Places. Check your connection.',
        code: 'network_error',
      );
    }

    if (response.statusCode != 200) {
      throw GooglePlacesException(
        'Google Places request failed (${response.statusCode}).',
        code: 'http_${response.statusCode}',
      );
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const GooglePlacesException(
        'Received an unexpected response from Google Places.',
        code: 'parse_error',
      );
    }

    final status = (body['status'] ?? '').toString();
    if (status == 'ZERO_RESULTS') {
      return const <NearbyPlace>[];
    }
    if (status != 'OK') {
      throw GooglePlacesException(
        (body['error_message'] ?? 'Google Places error: $status').toString(),
        code: status.toLowerCase(),
      );
    }

    final results = body['results'];
    if (results is! List) return const <NearbyPlace>[];

    final places = <NearbyPlace>[];
    for (final raw in results) {
      if (raw is! Map) continue;
      final place = _mapResult(
        raw.map((key, value) => MapEntry(key.toString(), value)),
        category: category,
        origin: origin,
      );
      if (place != null) places.add(place);
    }

    places.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return places;
  }

  NearbyPlace? _mapResult(
    Map<String, dynamic> result, {
    required NearbyPlaceCategory category,
    required Position origin,
  }) {
    final geometry = result['geometry'];
    final location = geometry is Map ? geometry['location'] : null;
    final latitude = _toDouble(location is Map ? location['lat'] : null);
    final longitude = _toDouble(location is Map ? location['lng'] : null);
    if (latitude == 0 && longitude == 0) return null;

    final name = (result['name'] ?? '').toString().trim();
    if (name.isEmpty) return null;

    final placeId = (result['place_id'] ?? '').toString().trim();
    final distanceMeters = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      latitude,
      longitude,
    );

    final openingHours = result['opening_hours'];
    final hasOpenNow = openingHours is Map &&
        openingHours.containsKey('open_now') &&
        openingHours['open_now'] != null;
    final openNow = hasOpenNow && openingHours['open_now'] == true;

    return NearbyPlace(
      placeId: placeId.isNotEmpty
          ? placeId
          : 'google_${category.cacheKey}_${latitude.toStringAsFixed(6)}_${longitude.toStringAsFixed(6)}',
      name: name,
      address:
          (result['vicinity'] ?? result['formatted_address'] ?? '').toString(),
      latitude: latitude,
      longitude: longitude,
      rating: _toDouble(result['rating']),
      openNow: openNow,
      openStatusKnown: hasOpenNow,
      distanceKm: double.parse((distanceMeters / 1000).toStringAsFixed(2)),
      category: category.serviceCategory,
      mapsUrl: _buildMapsSearchUrl(
        latitude: latitude,
        longitude: longitude,
        placeId: placeId,
      ),
    );
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

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  _PlacesStrategy _strategyForCategory(NearbyPlaceCategory category) {
    return switch (category) {
      NearbyPlaceCategory.all =>
        const _PlacesStrategy.textSearch('hospital OR clinic OR pharmacy'),
      NearbyPlaceCategory.hospitals =>
        const _PlacesStrategy.nearby('hospital'),
      NearbyPlaceCategory.clinics =>
        const _PlacesStrategy.textSearch('clinic'),
      NearbyPlaceCategory.doctors => const _PlacesStrategy.nearby('doctor'),
      NearbyPlaceCategory.medicalStores =>
        const _PlacesStrategy.nearby('pharmacy'),
      NearbyPlaceCategory.diagnosticLabs =>
        const _PlacesStrategy.textSearch('diagnostic lab'),
      NearbyPlaceCategory.ambulances =>
        const _PlacesStrategy.textSearch('ambulance service'),
    };
  }
}

class _PlacesStrategy {
  const _PlacesStrategy.nearby(this.placeType)
      : usesTextSearch = false,
        textQuery = null;

  const _PlacesStrategy.textSearch(this.textQuery)
      : usesTextSearch = true,
        placeType = null;

  final bool usesTextSearch;
  final String? placeType;
  final String? textQuery;
}
