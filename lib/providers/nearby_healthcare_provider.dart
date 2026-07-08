import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/nearby_place.dart';
import '../services/nearby_places_service.dart';
import '../services/offline/offline_storage_service.dart';

class NearbyHealthcareProvider extends ChangeNotifier {
  NearbyHealthcareProvider({
    NearbyPlacesService? placesService,
    OfflineStorageService? storage,
  })  : _placesService = placesService ?? NearbyPlacesService(),
        _storage = storage ?? OfflineStorageService.instance;

  static const int _pageSize = 12;

  final NearbyPlacesService _placesService;
  final OfflineStorageService _storage;
  final Map<NearbyPlaceCategory, List<NearbyPlace>> _placesByCategory = {};
  final Map<String, NearbyPlace> _favoritePlacesById = {};
  final Set<String> _inFlightLoads = {};

  NearbyPlaceCategory _selectedCategory = NearbyPlaceCategory.all;
  Position? _position;
  bool _loading = false;
  bool _usingCache = false;
  bool _usingStaleCache = false;
  String _message = '';
  String _searchQuery = '';
  double _radiusKm = 10;
  double _minimumRating = 0;
  bool _openNowOnly = false;
  int _visibleCount = _pageSize;
  List<String> _recentSearches = const <String>[];

  NearbyPlaceCategory get selectedCategory => _selectedCategory;
  Position? get position => _position;
  bool get loading => _loading;
  bool get usingCache => _usingCache;
  bool get usingStaleCache => _usingStaleCache;
  String get message => _message;
  String get searchQuery => _searchQuery;
  double get radiusKm => _radiusKm;
  double get minimumRating => _minimumRating;
  bool get openNowOnly => _openNowOnly;
  List<String> get recentSearches => List.unmodifiable(_recentSearches);
  Set<String> get favoritePlaceIds =>
      Set.unmodifiable(_favoritePlacesById.keys);

  List<NearbyPlace> get selectedCategoryPlaces =>
      List.unmodifiable(_placesByCategory[_selectedCategory] ?? const []);

  List<NearbyPlace> get filteredPlaces {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = selectedCategoryPlaces.where((place) {
      if (place.distanceKm > _radiusKm) return false;
      if (_minimumRating > 0 && place.rating < _minimumRating) return false;
      if (_openNowOnly && !place.openNow) return false;
      if (query.isEmpty) return true;
      return place.name.toLowerCase().contains(query) ||
          place.address.toLowerCase().contains(query);
    }).toList(growable: false)
      ..sort((a, b) {
        final distance = a.distanceKm.compareTo(b.distanceKm);
        if (distance != 0) return distance;
        return b.rating.compareTo(a.rating);
      });

    return filtered;
  }

  List<NearbyPlace> get visiblePlaces =>
      filteredPlaces.take(_visibleCount).toList(growable: false);

  bool get hasMoreVisiblePlaces => filteredPlaces.length > _visibleCount;

  Future<void> loadLocalState() async {
    final recent = await _storage.getNearbyRecentSearches();
    final favorites = await _storage.getNearbyFavoritePlaces();
    _recentSearches = recent;
    _favoritePlacesById
      ..clear()
      ..addEntries(
        favorites
            .map(NearbyPlace.fromJson)
            .where((place) => place.placeId.trim().isNotEmpty)
            .map((place) => MapEntry(place.placeId, place)),
      );
    notifyListeners();
  }

  Future<void> setCurrentPosition(
    Position position, {
    bool forceRefresh = false,
  }) async {
    _position = position;
    notifyListeners();
    await loadSelectedCategory(forceRefresh: forceRefresh);
  }

  Future<void> selectCategory(NearbyPlaceCategory category) async {
    if (_selectedCategory == category &&
        _placesByCategory.containsKey(category)) {
      return;
    }
    _selectedCategory = category;
    _visibleCount = _pageSize;
    _message = '';
    notifyListeners();
    await loadSelectedCategory();
  }

  Future<void> loadSelectedCategory({bool forceRefresh = false}) async {
    final origin = _position;
    if (origin == null) {
      _message = 'Location is required to find nearby services.';
      notifyListeners();
      return;
    }

    final loadKey =
        '${_selectedCategory.cacheKey}:${_radiusKm.toStringAsFixed(1)}';
    if (_inFlightLoads.contains(loadKey)) return;
    _inFlightLoads.add(loadKey);

    _loading = true;
    _usingCache = false;
    _usingStaleCache = false;
    _message = '';
    notifyListeners();

    try {
      final radiusMeters = _radiusKm * 1000;
      final places = switch (_selectedCategory) {
        NearbyPlaceCategory.all => await _placesService.getNearbyAll(
            origin: origin,
            radiusMeters: radiusMeters,
            forceRefresh: forceRefresh,
          ),
        NearbyPlaceCategory.hospitals =>
          await _placesService.getNearbyHospitals(
            origin: origin,
            radiusMeters: radiusMeters,
            forceRefresh: forceRefresh,
          ),
        NearbyPlaceCategory.clinics => await _placesService.getNearbyClinics(
            origin: origin,
            radiusMeters: radiusMeters,
            forceRefresh: forceRefresh,
          ),
        NearbyPlaceCategory.doctors => await _placesService.getNearbyDoctors(
            origin: origin,
            radiusMeters: radiusMeters,
            forceRefresh: forceRefresh,
          ),
        NearbyPlaceCategory.medicalStores =>
          await _placesService.getNearbyMedicalStores(
            origin: origin,
            radiusMeters: radiusMeters,
            forceRefresh: forceRefresh,
          ),
        NearbyPlaceCategory.diagnosticLabs =>
          await _placesService.getNearbyDiagnosticLabs(
            origin: origin,
            radiusMeters: radiusMeters,
            forceRefresh: forceRefresh,
          ),
        NearbyPlaceCategory.ambulances =>
          await _placesService.getNearbyAmbulances(
            origin: origin,
            radiusMeters: radiusMeters,
            forceRefresh: forceRefresh,
          ),
      };

      _placesByCategory[_selectedCategory] = places;
      _usingCache = _placesService.lastResultFromCache;
      _usingStaleCache = _placesService.lastResultWasStale;
      _message = _placesService.lastStatusMessage;
      if (places.isEmpty && _message.trim().isEmpty) {
        _message = 'No ${_selectedCategory.label.toLowerCase()} found nearby.';
      }
    } on NearbyPlacesException catch (error) {
      _message = error.message;
    } catch (_) {
      _message = 'Unable to load nearby healthcare services.';
    } finally {
      _loading = false;
      _inFlightLoads.remove(loadKey);
      notifyListeners();
    }
  }

  Future<void> refresh() {
    return loadSelectedCategory(forceRefresh: true);
  }

  Future<void> updateFilters({
    required double radiusKm,
    required double minimumRating,
    required bool openNowOnly,
  }) async {
    final radiusChanged = (_radiusKm - radiusKm).abs() > 0.1;
    _radiusKm = radiusKm;
    _minimumRating = minimumRating;
    _openNowOnly = openNowOnly;
    _visibleCount = _pageSize;
    notifyListeners();
    if (radiusChanged) {
      await loadSelectedCategory();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _visibleCount = _pageSize;
    notifyListeners();
  }

  Future<void> saveRecentSearch(String query) async {
    final value = query.trim();
    if (value.length < 2) return;
    final deduped = [
      value,
      ..._recentSearches.where(
        (entry) => entry.toLowerCase() != value.toLowerCase(),
      ),
    ].take(8).toList(growable: false);
    _recentSearches = deduped;
    await _storage.cacheNearbyRecentSearches(deduped);
    notifyListeners();
  }

  void loadMore() {
    if (!hasMoreVisiblePlaces) return;
    _visibleCount += _pageSize;
    notifyListeners();
  }

  bool isFavorite(NearbyPlace place) {
    return _favoritePlacesById.containsKey(place.placeId);
  }

  Future<void> toggleFavorite(NearbyPlace place) async {
    if (place.placeId.trim().isEmpty) return;
    if (_favoritePlacesById.containsKey(place.placeId)) {
      _favoritePlacesById.remove(place.placeId);
    } else {
      _favoritePlacesById[place.placeId] = place;
    }
    await _storage.cacheNearbyFavoritePlaces(
      _favoritePlacesById.values.map((place) => place.toJson()).toList(),
    );
    notifyListeners();
  }
}
