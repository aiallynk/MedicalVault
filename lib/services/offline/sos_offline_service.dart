import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'package:hello/api_service.dart';
import 'package:hello/services/offline/offline_storage_service.dart';
import 'package:hello/services/sos_sms_service.dart';

class SosDispatchResult {
  const SosDispatchResult({
    required this.success,
    required this.usedOfflineFallback,
    required this.queuedForSync,
    this.recipientCount = 0,
    this.recipients = const <String>[],
    this.smsMessage = '',
    this.primaryRecipient,
    this.backendResponse,
    this.message = '',
    this.eventId,
    this.smsAttemptedCount = 0,
    this.smsSentCount = 0,
    this.smsResults = const <Map<String, dynamic>>[],
    this.smsPermissionDenied = false,
    this.smsPermissionPermanentlyDenied = false,
    this.openedSmsComposer = false,
  });

  final bool success;
  final bool usedOfflineFallback;
  final bool queuedForSync;
  final int recipientCount;
  final List<String> recipients;
  final String smsMessage;
  final String? primaryRecipient;
  final Map<String, dynamic>? backendResponse;
  final String message;
  final String? eventId;
  final int smsAttemptedCount;
  final int smsSentCount;
  final List<Map<String, dynamic>> smsResults;
  final bool smsPermissionDenied;
  final bool smsPermissionPermanentlyDenied;
  final bool openedSmsComposer;
}

class SosOfflineService {
  SosOfflineService._internal();
  static final SosOfflineService instance = SosOfflineService._internal();
  static const Uuid _uuid = Uuid();

  Future<SosDispatchResult> sendSos({
    double? latitude,
    double? longitude,
    required Map<String, dynamic> userData,
    double? accuracyMeters,
    String? notes,
    String? allergies,
    String? name,
    String? mobile,
    String? age,
    String? locationText,
    String? profileId,
  }) async {
    await OfflineStorageService.instance.initialize();

    final cleanNotes = _safeText(notes);
    final cleanAllergies = _safeText(allergies);
    final cleanName = _safeText(name);
    final cleanMobile = _safePhone(mobile);
    final cleanAge = _safeText(age);
    final cleanLocationText = _safeText(locationText);
    final cleanProfileId = _safeText(profileId);
    final timestamp = DateTime.now();
    final eventId = _uuid.v4();
    final hasLocation = latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite;

    final payload = <String, dynamic>{
      'eventId': eventId,
      if (hasLocation) 'latitude': latitude,
      if (hasLocation) 'longitude': longitude,
      if (accuracyMeters != null && accuracyMeters.isFinite)
        'accuracyMeters': accuracyMeters,
      if (cleanNotes.isNotEmpty) 'notes': cleanNotes,
      if (cleanAllergies.isNotEmpty) 'allergies': cleanAllergies,
      if (cleanName.isNotEmpty) 'name': cleanName,
      if (cleanMobile.isNotEmpty) 'mobile': cleanMobile,
      if (cleanAge.isNotEmpty) 'age': cleanAge,
      if (cleanLocationText.isNotEmpty) 'locationText': cleanLocationText,
      if (cleanProfileId.isNotEmpty) 'profileId': cleanProfileId,
      'capturedAt': timestamp.toIso8601String(),
    };

    await OfflineStorageService.instance.cacheUserData(userData);
    if (hasLocation) {
      await OfflineStorageService.instance.cacheLastKnownLocation(
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracyMeters,
        locationText: locationText,
        capturedAt: timestamp,
      );
    }

    final isOnline = await _isOnline();
    var contacts = await OfflineStorageService.instance.getEmergencyContacts();
    if (contacts.isEmpty) {
      final extracted =
          OfflineStorageService.extractEmergencyContacts(userData);
      if (extracted.isNotEmpty) {
        await OfflineStorageService.instance.cacheEmergencyContacts(extracted);
        contacts = extracted;
      }
    }
    final activeContacts = _activeUniqueContacts(contacts);
    final phones = activeContacts
        .map((entry) => (entry['phone'] ?? '').toString().trim())
        .toList(growable: false);

    final smsMessage = _buildSmsMessage(
      name: name ?? userData['name']?.toString(),
      mobile: mobile ?? userData['mobile']?.toString(),
      profileId: cleanProfileId.isNotEmpty ? cleanProfileId : null,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      locationText: locationText,
    );

    if (phones.isEmpty) {
      final event = {
        ..._buildEventLog(
          eventId: eventId,
          userData: userData,
          payload: payload,
          timestamp: timestamp,
          source: _source,
          networkMode: isOnline ? 'online' : 'offline',
          message: smsMessage,
          contacts: const <Map<String, dynamic>>[],
          smsResults: const <Map<String, dynamic>>[],
          latitude: latitude,
          longitude: longitude,
          accuracyMeters: accuracyMeters,
          syncStatus: 'pending',
        ),
        'dispatchStatus': 'no_contacts',
      };
      final sync = await _persistAndSyncEvent(event, isOnline: isOnline);
      return SosDispatchResult(
        success: false,
        usedOfflineFallback: !isOnline,
        queuedForSync: sync.queued,
        eventId: eventId,
        message:
            'No emergency contacts configured. Add an emergency contact in profile settings.',
      );
    }

    final initialEvent = {
      ..._buildEventLog(
        eventId: eventId,
        userData: userData,
        payload: payload,
        timestamp: timestamp,
        source: _source,
        networkMode: isOnline ? 'online' : 'offline',
        message: smsMessage,
        contacts: activeContacts,
        smsResults: const <Map<String, dynamic>>[],
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracyMeters,
        syncStatus: 'pending',
      ),
      'dispatchStatus': 'sending',
    };
    await OfflineStorageService.instance.upsertLocalSosEvent(initialEvent);

    final smsResults = <Map<String, dynamic>>[];
    bool smsPermissionDenied = false;
    bool smsPermissionPermanentlyDenied = false;
    bool openedComposer = false;

    if (Platform.isAndroid) {
      final permission =
          await SosSmsService.instance.requestSmsPermissionForSos();
      if (permission.isGranted) {
        for (final contact in activeContacts) {
          final phone = (contact['phone'] ?? '').toString().trim();
          final result = await SosSmsService.instance.sendEmergencySms(
            recipient: phone,
            message: smsMessage,
          );
          smsResults.add({
            ...contact,
            ...result.toJson(),
            'status': result.success ? 'sent' : 'failed',
            'sentAt': DateTime.now().toIso8601String(),
          });
        }
      } else {
        smsPermissionDenied = true;
        smsPermissionPermanentlyDenied = permission.isPermanentlyDenied;
        openedComposer = await SosSmsService.instance.openSmsComposer(
          recipients: phones,
          message: smsMessage,
        );
        for (final contact in activeContacts) {
          smsResults.add({
            ...contact,
            'recipient': contact['phone'],
            'success': openedComposer,
            'status':
                openedComposer ? 'composer_opened' : 'sms_permission_denied',
            'errorCode': permission.isPermanentlyDenied
                ? 'SMS_PERMISSION_PERMANENTLY_DENIED'
                : 'SMS_PERMISSION_DENIED',
            'errorMessage': openedComposer
                ? null
                : 'SMS permission required to send automatically.',
          });
        }
      }
    } else {
      openedComposer = await SosSmsService.instance.openSmsComposer(
        recipients: phones,
        message: smsMessage,
      );
      for (final contact in activeContacts) {
        smsResults.add({
          ...contact,
          'recipient': contact['phone'],
          'success': openedComposer,
          'status': openedComposer ? 'composer_opened' : 'composer_failed',
          'errorCode': openedComposer ? null : 'COMPOSER_UNAVAILABLE',
          'errorMessage': openedComposer
              ? null
              : 'Automatic SMS is not supported on this platform.',
        });
      }
    }

    final sentCount = smsResults
        .where((entry) => entry['success'] == true && entry['status'] == 'sent')
        .length;
    final deliverySucceeded = sentCount > 0 || openedComposer;

    final event = {
      ..._buildEventLog(
        eventId: eventId,
        userData: userData,
        payload: payload,
        timestamp: timestamp,
        source: _source,
        networkMode: isOnline ? 'online' : 'offline',
        message: smsMessage,
        contacts: activeContacts,
        smsResults: smsResults,
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracyMeters,
        syncStatus: 'pending',
      ),
      'dispatchStatus': 'completed',
    };
    final sync = await _persistAndSyncEvent(event, isOnline: isOnline);

    final failedCount =
        smsResults.where((entry) => entry['success'] != true).length;
    final resultMessage = _resultMessage(
      attempted: activeContacts.length,
      sent: sentCount,
      failed: failedCount,
      openedComposer: openedComposer,
      smsPermissionDenied: smsPermissionDenied,
      smsPermissionPermanentlyDenied: smsPermissionPermanentlyDenied,
      queuedForSync: sync.queued,
    );

    return SosDispatchResult(
      success: deliverySucceeded,
      usedOfflineFallback: !isOnline || openedComposer,
      queuedForSync: sync.queued,
      recipientCount: phones.length,
      recipients: phones,
      smsMessage: smsMessage,
      primaryRecipient: phones.first,
      backendResponse: sync.response,
      message: resultMessage,
      eventId: eventId,
      smsAttemptedCount: activeContacts.length,
      smsSentCount: sentCount,
      smsResults: smsResults,
      smsPermissionDenied: smsPermissionDenied,
      smsPermissionPermanentlyDenied: smsPermissionPermanentlyDenied,
      openedSmsComposer: openedComposer,
    );
  }

  Future<bool> openSmsFallback({
    required List<String> recipients,
    required String message,
  }) {
    return _sendFallbackSms(
      recipients: recipients,
      message: message,
    );
  }

  Future<bool> openCallFallback({
    required String phone,
  }) {
    return _triggerFallbackCall(phone);
  }

  Future<bool> _isOnline() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    return connectivityResults.any(
      (entry) => entry != ConnectivityResult.none,
    );
  }

  String _buildSmsMessage({
    String? name,
    String? mobile,
    String? profileId,
    double? latitude,
    double? longitude,
    required DateTime timestamp,
    String? locationText,
  }) {
    final safeName = _safeText(name);
    final safeMobile = _safeText(mobile);
    final safeProfileId = _safeText(profileId);
    final timeText = timestamp.toLocal().toIso8601String().split('.').first;
    final hasLocation = latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite;

    final buffer = StringBuffer();
    buffer.write('SOS Alert from Medical Vault: ');
    buffer.write(safeName.isNotEmpty ? safeName : 'A user');
    buffer.write(' may need urgent help.');
    if (safeMobile.isNotEmpty) buffer.write(' Phone: $safeMobile.');
    if (safeProfileId.isNotEmpty) buffer.write(' ID: $safeProfileId.');
    buffer.write(' Time: $timeText.');
    if (hasLocation) {
      buffer.write(
        ' Location: https://maps.google.com/?q=$latitude,$longitude.',
      );
    } else {
      buffer.write(' Location unavailable.');
    }
    buffer.write(' Please contact immediately.');
    return buffer.toString().trim();
  }

  String get _source {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }

  List<Map<String, dynamic>> _activeUniqueContacts(
    List<Map<String, dynamic>> contacts,
  ) {
    final seen = <String>{};
    final output = <Map<String, dynamic>>[];
    for (final raw in contacts) {
      if (raw['active'] == false) continue;
      final phone = SosSmsService.instance.normalizePhone(
        (raw['phone'] ?? raw['mobile'] ?? raw['number'] ?? '').toString(),
      );
      if (!SosSmsService.instance.isValidPhone(phone)) continue;
      if (seen.contains(phone)) continue;
      seen.add(phone);
      final priority =
          int.tryParse((raw['priority'] ?? raw['order'] ?? '').toString()) ??
              output.length;
      output.add({
        'name': _safeText((raw['name'] ?? '').toString()).isNotEmpty
            ? _safeText((raw['name'] ?? '').toString())
            : 'Emergency Contact',
        'phone': phone,
        'relation': _safeText(
          (raw['relation'] ?? raw['relationship'] ?? '').toString(),
        ),
        'relationship': _safeText(
          (raw['relationship'] ?? raw['relation'] ?? '').toString(),
        ),
        'priority': priority,
        'active': true,
      });
    }
    output.sort((a, b) {
      final left = int.tryParse((a['priority'] ?? 999).toString()) ?? 999;
      final right = int.tryParse((b['priority'] ?? 999).toString()) ?? 999;
      return left.compareTo(right);
    });
    return output;
  }

  Map<String, dynamic> _buildEventLog({
    required String eventId,
    required Map<String, dynamic> userData,
    required Map<String, dynamic> payload,
    required DateTime timestamp,
    required String source,
    required String networkMode,
    required String message,
    required List<Map<String, dynamic>> contacts,
    required List<Map<String, dynamic>> smsResults,
    required String syncStatus,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
  }) {
    final userId = _safeText(
      (userData['id'] ?? userData['_id'] ?? userData['userId'] ?? '')
          .toString(),
    );
    final hasLocation = latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite;

    return {
      'eventId': eventId,
      'userId': userId,
      'profileId': payload['profileId'] ?? userId,
      'userName': payload['name'] ?? userData['name'] ?? '',
      'phone': payload['mobile'] ?? userData['mobile'] ?? '',
      'timestamp': timestamp.toIso8601String(),
      'messagePreview': message,
      'source': source,
      'networkMode': networkMode,
      'syncStatus': syncStatus,
      'attemptedContacts': contacts,
      'recipients': smsResults.map((entry) {
        return {
          'name': entry['name'],
          'phone': entry['phone'] ?? entry['recipient'],
          'relation': entry['relation'] ?? entry['relationship'],
          'status': entry['status'],
          'error': entry['errorMessage'] ?? entry['errorCode'],
        };
      }).toList(growable: false),
      if (hasLocation)
        'location': {
          'lat': latitude,
          'lng': longitude,
          if (accuracyMeters != null && accuracyMeters.isFinite)
            'accuracy': accuracyMeters,
          'mapsUrl': 'https://maps.google.com/?q=$latitude,$longitude',
        }
      else
        'location': {
          'mapsUrl': '',
          'unavailable': true,
        },
      'payload': payload,
    };
  }

  Future<_SosEventSyncResult> _persistAndSyncEvent(
    Map<String, dynamic> event, {
    required bool isOnline,
  }) async {
    await OfflineStorageService.instance.upsertLocalSosEvent(event);
    if (!isOnline) {
      await _queueEventSync(event);
      return const _SosEventSyncResult(queued: true);
    }

    final response = await ApiService.createSosEvent(event).timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );
    if (response != null && response['success'] == true) {
      final synced = {
        ...event,
        'syncStatus': 'synced',
        'backendResponse': response,
      };
      await OfflineStorageService.instance.upsertLocalSosEvent(synced);
      return _SosEventSyncResult(queued: false, response: response);
    }

    await _queueEventSync(event);
    return const _SosEventSyncResult(queued: true);
  }

  Future<void> _queueEventSync(Map<String, dynamic> event) async {
    await OfflineStorageService.instance.enqueuePendingAction(
      type: 'sos_event',
      payload: event,
      metadata: {
        'eventId': event['eventId'],
        'recipientCount': (event['recipients'] is List)
            ? (event['recipients'] as List).length
            : 0,
      },
    );
  }

  String _resultMessage({
    required int attempted,
    required int sent,
    required int failed,
    required bool openedComposer,
    required bool smsPermissionDenied,
    required bool smsPermissionPermanentlyDenied,
    required bool queuedForSync,
  }) {
    if (openedComposer) {
      if (Platform.isIOS) {
        return 'SMS composer opened. iOS does not allow automatic offline SMS.';
      }
      if (smsPermissionPermanentlyDenied) {
        return 'SMS permission is permanently denied. SMS composer opened; enable SMS permission in Settings for automatic SOS.';
      }
      if (smsPermissionDenied) {
        return 'SMS permission required. SMS composer opened as fallback.';
      }
      return 'SMS composer opened.';
    }
    if (sent == attempted && attempted > 0) {
      return queuedForSync
          ? 'SMS sent to $sent/$attempted contacts. SOS log will sync when internet returns.'
          : 'SMS sent to $sent/$attempted contacts.';
    }
    if (sent > 0) {
      return 'SMS sent to $sent/$attempted contacts. Some contacts failed.';
    }
    if (failed > 0) {
      return 'Some contacts failed. SMS sent to 0/$attempted contacts.';
    }
    return 'Failed to send SOS SMS.';
  }

  String _safeText(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '';
    if (raw.toLowerCase().startsWith('enc:v')) return '';
    return raw;
  }

  String _safePhone(String? value) {
    final cleaned = _safeText(value)
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('(', '')
        .replaceAll(')', '');
    if (cleaned.isEmpty) return '';
    final validPattern = RegExp(r'^\+?\d{7,15}$');
    if (!validPattern.hasMatch(cleaned)) return '';
    return cleaned;
  }

  Future<bool> _sendFallbackSms({
    required List<String> recipients,
    required String message,
  }) async {
    if (recipients.isEmpty) return false;

    try {
      final cleanedRecipients = recipients
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
      if (cleanedRecipients.isEmpty) return false;

      final uri = Uri(
        scheme: 'sms',
        path: cleanedRecipients.join(','),
        queryParameters: {'body': message},
      );
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      final firstRecipientUri = Uri(
        scheme: 'sms',
        path: cleanedRecipients.first,
        queryParameters: {'body': message},
      );
      if (await canLaunchUrl(firstRecipientUri)) {
        return launchUrl(
          firstRecipientUri,
          mode: LaunchMode.externalApplication,
        );
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _triggerFallbackCall(String phone) async {
    final first = phone.trim();
    if (first.isEmpty) return false;

    try {
      await Permission.phone.request();
      final uri = Uri(scheme: 'tel', path: first);
      if (!await canLaunchUrl(uri)) return false;
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Call fallback failed: $error');
      }
      return false;
    }
  }

  String debugToJson(SosDispatchResult result) {
    return jsonEncode({
      'success': result.success,
      'usedOfflineFallback': result.usedOfflineFallback,
      'queuedForSync': result.queuedForSync,
      'recipientCount': result.recipientCount,
      'recipients': result.recipients,
      'primaryRecipient': result.primaryRecipient,
      'message': result.message,
      'eventId': result.eventId,
      'smsAttemptedCount': result.smsAttemptedCount,
      'smsSentCount': result.smsSentCount,
      'smsResults': result.smsResults,
      'smsPermissionDenied': result.smsPermissionDenied,
      'smsPermissionPermanentlyDenied': result.smsPermissionPermanentlyDenied,
      'openedSmsComposer': result.openedSmsComposer,
      'backendResponse': result.backendResponse,
    });
  }
}

class _SosEventSyncResult {
  const _SosEventSyncResult({
    required this.queued,
    this.response,
  });

  final bool queued;
  final Map<String, dynamic>? response;
}
