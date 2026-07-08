import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'package:hello/api_service.dart';
import 'package:hello/services/offline/offline_storage_service.dart';

const String _offlineSyncTaskName = 'offline_sync_pending_actions';

@pragma('vm:entry-point')
void offlineSyncBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await OfflineStorageService.instance.initialize();
      await OfflineSyncEngine.instance.syncPendingActions(
        trigger: 'workmanager',
      );
    } catch (_) {
      // Avoid crashing background isolate.
    }
    return Future.value(true);
  });
}

class OfflineSyncEngine {
  OfflineSyncEngine._internal();
  static final OfflineSyncEngine instance = OfflineSyncEngine._internal();

  StreamSubscription<dynamic>? _connectivitySubscription;
  bool _initialized = false;
  bool _syncInProgress = false;
  DateTime _lastSyncAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await OfflineStorageService.instance.initialize();
    await _configureBackgroundSync();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((dynamic result) {
      if (_hasConnection(result)) {
        unawaited(syncPendingActions(trigger: 'connectivity_change'));
      }
    });

    final initialResult = await Connectivity().checkConnectivity();
    if (_hasConnection(initialResult)) {
      unawaited(syncPendingActions(trigger: 'startup'));
    }
  }

  Future<void> _configureBackgroundSync() async {
    try {
      await Workmanager().initialize(
        offlineSyncBackgroundDispatcher,
        isInDebugMode: false,
      );

      await Workmanager().registerPeriodicTask(
        'offline_sync_periodic_v1',
        _offlineSyncTaskName,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Workmanager setup skipped: $error');
      }
    }
  }

  bool _hasConnection(dynamic result) {
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }

    if (result is List<ConnectivityResult>) {
      return result.any((entry) => entry != ConnectivityResult.none);
    }

    if (result is Iterable) {
      return result.any((entry) => entry != ConnectivityResult.none);
    }

    return false;
  }

  Future<void> syncPendingActions({String trigger = 'manual'}) async {
    if (_syncInProgress) return;

    final now = DateTime.now();
    if (now.difference(_lastSyncAt) < const Duration(seconds: 5)) {
      return;
    }
    _lastSyncAt = now;

    final connection = await Connectivity().checkConnectivity();
    if (!_hasConnection(connection)) return;

    _syncInProgress = true;
    try {
      final pending = await OfflineStorageService.instance.getPendingActions();
      if (pending.isEmpty) return;

      for (final action in pending) {
        final id = (action['id'] ?? '').toString().trim();
        final type = (action['type'] ?? '').toString().trim().toLowerCase();
        final payload = action['payload'];

        if (id.isEmpty || payload is! Map) continue;
        final normalizedPayload = payload.map(
          (key, value) => MapEntry(key.toString(), value),
        );

        bool success = false;
        if (type == 'sos_event') {
          final response = await ApiService.createSosEvent(normalizedPayload);
          success = response != null && response['success'] == true;
        } else if (type == 'sos') {
          final response = await ApiService.createSos(
            latitude: double.tryParse(
                    (normalizedPayload['latitude'] ?? '').toString()) ??
                0,
            longitude: double.tryParse(
                    (normalizedPayload['longitude'] ?? '').toString()) ??
                0,
            accuracyMeters: double.tryParse(
                (normalizedPayload['accuracyMeters'] ?? '').toString()),
            notes: normalizedPayload['notes']?.toString(),
            allergies: normalizedPayload['allergies']?.toString(),
            name: normalizedPayload['name']?.toString(),
            mobile: normalizedPayload['mobile']?.toString(),
            age: normalizedPayload['age']?.toString(),
            locationText: normalizedPayload['locationText']?.toString(),
            profileId: normalizedPayload['profileId']?.toString(),
          );
          success = response != null && response['success'] == true;
        }

        if (success) {
          await OfflineStorageService.instance.removePendingAction(id);
          if (type == 'sos_event') {
            await OfflineStorageService.instance.upsertLocalSosEvent({
              ...normalizedPayload,
              'syncStatus': 'synced',
              'syncTrigger': trigger,
              'actionId': id,
            });
          } else {
            await OfflineStorageService.instance.appendLocalSosEvent({
              'status': 'synced',
              'syncTrigger': trigger,
              'actionId': id,
              'payload': normalizedPayload,
            });
          }
        } else {
          await OfflineStorageService.instance.markPendingActionAttempted(id);
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Offline sync failed: $error');
      }
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _initialized = false;
  }
}
