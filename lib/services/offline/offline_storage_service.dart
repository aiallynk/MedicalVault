import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class OfflineStorageService {
  OfflineStorageService._internal();
  static final OfflineStorageService instance =
      OfflineStorageService._internal();

  static const String _boxName = 'offline_secure_v1';
  static const String _hiveKeyStorageName = 'offline_hive_key_v1';

  static const String _userDataKey = 'user_data';
  static const String _emergencyContactsKey = 'emergency_contacts';
  static const String _lastKnownLocationKey = 'last_known_location';
  static const String _pendingActionsKey = 'pending_actions';
  static const String _localSosEventsKey = 'local_sos_events';
  static const String _nearbyServicesCacheKey = 'nearby_services_cache';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Box<dynamic>? _box;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized && _box != null && _box!.isOpen) return;

    await Hive.initFlutter();
    final encryptionKey = await _readOrCreateEncryptionKey();
    _box = await Hive.openBox<dynamic>(
      _boxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
    _initialized = true;
  }

  Future<Uint8List> _readOrCreateEncryptionKey() async {
    final existing = await _secureStorage.read(key: _hiveKeyStorageName);
    if (existing != null && existing.trim().isNotEmpty) {
      try {
        return base64Url.decode(existing);
      } catch (_) {
        // Fall through and regenerate.
      }
    }

    final random = Random.secure();
    final key = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await _secureStorage.write(
      key: _hiveKeyStorageName,
      value: base64UrlEncode(key),
    );
    return key;
  }

  Future<void> _ensureReady() async {
    if (!_initialized || _box == null || !_box!.isOpen) {
      await initialize();
    }
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, data) => MapEntry(key.toString(), data));
    }
    return null;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map(
            (entry) => entry.map((key, data) => MapEntry(key.toString(), data)))
        .toList(growable: true);
  }

  static String _sanitizeText(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '';
    if (raw.toLowerCase().startsWith('enc:v')) return '';
    return raw;
  }

  static String _sanitizePhone(dynamic value) {
    final raw = _sanitizeText(value);
    if (raw.isEmpty) return '';

    final compact = raw
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('(', '')
        .replaceAll(')', '');
    final validPattern = RegExp(r'^\+?\d{7,15}$');
    if (!validPattern.hasMatch(compact)) return '';
    return compact;
  }

  Future<void> cacheUserData(Map<String, dynamic> userData) async {
    await _ensureReady();
    await _box!.put(_userDataKey, Map<String, dynamic>.from(userData));
  }

  Future<Map<String, dynamic>?> getCachedUserData() async {
    await _ensureReady();
    return _asMap(_box!.get(_userDataKey));
  }

  static List<Map<String, dynamic>> extractEmergencyContacts(
    Map<String, dynamic>? userData,
  ) {
    final output = <Map<String, dynamic>>[];
    if (userData == null) return output;

    final emergencyContact = userData['emergencyContact'];
    if (emergencyContact is Map) {
      final phone = _sanitizePhone(
        emergencyContact['phone'] ??
            emergencyContact['mobile'] ??
            emergencyContact['number'],
      );
      if (phone.isNotEmpty) {
        output.add({
          'name': _sanitizeText(emergencyContact['name']).isNotEmpty
              ? _sanitizeText(emergencyContact['name'])
              : 'Emergency Contact',
          'phone': phone,
          'relationship': _sanitizeText(emergencyContact['relationship']),
        });
      }
    }

    final emergencyContacts = userData['emergencyContacts'];
    if (emergencyContacts is List) {
      for (final entry in emergencyContacts) {
        if (entry is! Map) continue;
        final phone = _sanitizePhone(
            entry['phone'] ?? entry['mobile'] ?? entry['number']);
        if (phone.isEmpty) continue;
        output.add({
          'name': _sanitizeText(entry['name']).isNotEmpty
              ? _sanitizeText(entry['name'])
              : 'Emergency Contact',
          'phone': phone,
          'relationship': _sanitizeText(entry['relationship']),
        });
      }
    }

    final seen = <String>{};
    return output.where((contact) {
      final phone = (contact['phone'] ?? '').toString();
      if (phone.isEmpty || seen.contains(phone)) return false;
      seen.add(phone);
      return true;
    }).toList(growable: false);
  }

  Future<void> cacheEmergencyContacts(
      List<Map<String, dynamic>> contacts) async {
    await _ensureReady();
    final normalized = contacts
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
    await _box!.put(_emergencyContactsKey, normalized);
  }

  Future<void> cacheEmergencyContactsFromUserData(
    Map<String, dynamic>? userData,
  ) async {
    if (userData == null) return;
    final hasContactFields = userData.containsKey('emergencyContact') ||
        userData.containsKey('emergencyContacts');
    if (!hasContactFields) return;

    final extracted = extractEmergencyContacts(userData);

    if (extracted.isEmpty) {
      final emergencyContact = userData['emergencyContact'];
      if (emergencyContact is Map) {
        final rawPhone = (emergencyContact['phone'] ??
                emergencyContact['mobile'] ??
                emergencyContact['number'] ??
                '')
            .toString()
            .trim();
        if (rawPhone.toLowerCase().startsWith('enc:v')) {
          // Backend returned encrypted value; keep existing local plain cache.
          return;
        }
      }
    }

    // Always persist extracted value so cleared contacts are reflected too.
    await cacheEmergencyContacts(extracted);
  }

  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    await _ensureReady();
    return _asMapList(_box!.get(_emergencyContactsKey));
  }

  Future<void> cacheLastKnownLocation({
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    String? locationText,
    DateTime? capturedAt,
  }) async {
    await _ensureReady();
    await _box!.put(_lastKnownLocationKey, {
      'latitude': latitude,
      'longitude': longitude,
      if (accuracyMeters != null && accuracyMeters.isFinite)
        'accuracyMeters': accuracyMeters,
      if (locationText != null && locationText.trim().isNotEmpty)
        'locationText': locationText.trim(),
      'capturedAt': (capturedAt ?? DateTime.now()).toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getLastKnownLocation() async {
    await _ensureReady();
    return _asMap(_box!.get(_lastKnownLocationKey));
  }

  String _actionId(String type) {
    final random = Random.secure().nextInt(999999).toString().padLeft(6, '0');
    return '${type}_${DateTime.now().microsecondsSinceEpoch}_$random';
  }

  Future<String> enqueuePendingAction({
    required String type,
    required Map<String, dynamic> payload,
    Map<String, dynamic>? metadata,
  }) async {
    await _ensureReady();
    final now = DateTime.now().toIso8601String();
    final action = <String, dynamic>{
      'id': _actionId(type),
      'type': type,
      'payload': Map<String, dynamic>.from(payload),
      if (metadata != null) 'metadata': Map<String, dynamic>.from(metadata),
      'createdAt': now,
      'updatedAt': now,
      'attempts': 0,
    };

    final existing = _asMapList(_box!.get(_pendingActionsKey));
    existing.add(action);
    await _box!.put(_pendingActionsKey, existing);
    return action['id'] as String;
  }

  Future<List<Map<String, dynamic>>> getPendingActions({String? type}) async {
    await _ensureReady();
    final all = _asMapList(_box!.get(_pendingActionsKey));
    final normalizedType = (type ?? '').trim().toLowerCase();
    if (normalizedType.isEmpty) return all;
    return all
        .where(
          (entry) =>
              (entry['type'] ?? '').toString().trim().toLowerCase() ==
              normalizedType,
        )
        .toList(growable: false);
  }

  Future<void> removePendingAction(String actionId) async {
    await _ensureReady();
    final all = _asMapList(_box!.get(_pendingActionsKey));
    all.removeWhere((entry) => (entry['id'] ?? '').toString() == actionId);
    await _box!.put(_pendingActionsKey, all);
  }

  Future<void> markPendingActionAttempted(String actionId) async {
    await _ensureReady();
    final all = _asMapList(_box!.get(_pendingActionsKey));
    for (final action in all) {
      if ((action['id'] ?? '').toString() != actionId) continue;
      final attempts = int.tryParse((action['attempts'] ?? 0).toString()) ?? 0;
      action['attempts'] = attempts + 1;
      action['updatedAt'] = DateTime.now().toIso8601String();
      break;
    }
    await _box!.put(_pendingActionsKey, all);
  }

  Future<void> appendLocalSosEvent(Map<String, dynamic> event) async {
    await _ensureReady();
    final existing = _asMapList(_box!.get(_localSosEventsKey));
    existing.add({
      ...Map<String, dynamic>.from(event),
      'loggedAt': DateTime.now().toIso8601String(),
    });

    // Keep only recent events to avoid uncontrolled growth.
    final trimmed = existing.length > 100
        ? existing.sublist(existing.length - 100)
        : existing;
    await _box!.put(_localSosEventsKey, trimmed);
  }

  Future<List<Map<String, dynamic>>> getLocalSosEvents() async {
    await _ensureReady();
    return _asMapList(_box!.get(_localSosEventsKey));
  }

  Future<void> cacheNearbyServices(Map<String, dynamic> payload) async {
    await _ensureReady();
    await _box!.put(
      _nearbyServicesCacheKey,
      Map<String, dynamic>.from(payload),
    );
  }

  Future<Map<String, dynamic>?> getCachedNearbyServices() async {
    await _ensureReady();
    return _asMap(_box!.get(_nearbyServicesCacheKey));
  }

  void dispose() {
    try {
      _box?.close();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('OfflineStorageService close error: $error');
      }
    }
    _initialized = false;
    _box = null;
  }
}
