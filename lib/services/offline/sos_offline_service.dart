import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hello/api_service.dart';
import 'package:hello/services/offline/offline_storage_service.dart';

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
}

class SosOfflineService {
  SosOfflineService._internal();
  static final SosOfflineService instance = SosOfflineService._internal();

  Future<SosDispatchResult> sendSos({
    required double latitude,
    required double longitude,
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

    final payload = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      if (accuracyMeters != null && accuracyMeters.isFinite)
        'accuracyMeters': accuracyMeters,
      if (cleanNotes.isNotEmpty) 'notes': cleanNotes,
      if (cleanAllergies.isNotEmpty) 'allergies': cleanAllergies,
      if (cleanName.isNotEmpty) 'name': cleanName,
      if (cleanMobile.isNotEmpty) 'mobile': cleanMobile,
      if (cleanAge.isNotEmpty) 'age': cleanAge,
      if (cleanLocationText.isNotEmpty) 'locationText': cleanLocationText,
      if (cleanProfileId.isNotEmpty) 'profileId': cleanProfileId,
      'capturedAt': DateTime.now().toIso8601String(),
    };

    await OfflineStorageService.instance.cacheUserData(userData);
    await OfflineStorageService.instance.cacheLastKnownLocation(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      locationText: locationText,
      capturedAt: DateTime.now(),
    );

    final isOnline = await _isOnline();
    if (isOnline) {
      final response = await ApiService.createSos(
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracyMeters,
        notes: cleanNotes.isNotEmpty ? cleanNotes : null,
        allergies: cleanAllergies.isNotEmpty ? cleanAllergies : null,
        name: cleanName.isNotEmpty ? cleanName : null,
        mobile: cleanMobile.isNotEmpty ? cleanMobile : null,
        age: cleanAge.isNotEmpty ? cleanAge : null,
        locationText: cleanLocationText.isNotEmpty ? cleanLocationText : null,
        profileId: cleanProfileId.isNotEmpty ? cleanProfileId : null,
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () => null,
      );

      if (response != null && response['success'] == true) {
        await OfflineStorageService.instance.appendLocalSosEvent({
          'status': 'sent_online',
          'payload': payload,
          'backendResponse': response,
        });
        return SosDispatchResult(
          success: true,
          usedOfflineFallback: false,
          queuedForSync: false,
          backendResponse: response,
        );
      }
    }

    var contacts = await OfflineStorageService.instance.getEmergencyContacts();
    if (contacts.isEmpty) {
      final extracted =
          OfflineStorageService.extractEmergencyContacts(userData);
      if (extracted.isNotEmpty) {
        await OfflineStorageService.instance.cacheEmergencyContacts(extracted);
        contacts = extracted;
      }
    }
    final phones = contacts
        .map((entry) => (entry['phone'] ?? '').toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final smsMessage = _buildSmsMessage(
      name: name ?? userData['name']?.toString(),
      mobile: mobile ?? userData['mobile']?.toString(),
      latitude: latitude,
      longitude: longitude,
      notes: notes,
      locationText: locationText,
    );

    await OfflineStorageService.instance.enqueuePendingAction(
      type: 'sos',
      payload: payload,
      metadata: {
        'recipientCount': phones.length,
      },
    );
    await OfflineStorageService.instance.appendLocalSosEvent({
      'status': 'queued_offline',
      'payload': payload,
      'recipientCount': phones.length,
      'recipients': phones,
    });

    if (phones.isEmpty) {
      return const SosDispatchResult(
        success: false,
        usedOfflineFallback: true,
        queuedForSync: true,
        message:
            'No emergency contacts found for offline fallback. SOS was queued for sync. Please add emergency contacts to enable SMS/Call.',
      );
    }

    return SosDispatchResult(
      success: true,
      usedOfflineFallback: true,
      queuedForSync: true,
      recipientCount: phones.length,
      recipients: phones,
      smsMessage: smsMessage,
      primaryRecipient: phones.first,
      message:
          'Offline SOS queued for sync. Choose SMS or Call to notify contacts now.',
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
    required double latitude,
    required double longitude,
    String? notes,
    String? locationText,
  }) {
    final safeName = _safeText(name);
    final safeMobile = _safeText(mobile);
    final safeNotes = _safeText(notes);
    final safeLocationText = _safeText(locationText);

    final buffer = StringBuffer();
    buffer.writeln('EMERGENCY SOS ALERT');
    if (safeName.isNotEmpty) {
      buffer.writeln('Name: $safeName');
    }
    if (safeMobile.isNotEmpty) {
      buffer.writeln('Mobile: $safeMobile');
    }
    buffer.writeln('Location: $latitude, $longitude');
    if (safeLocationText.isNotEmpty) {
      buffer.writeln('Location text: $safeLocationText');
    }
    buffer.writeln(
      'Maps: https://maps.google.com/?q=$latitude,$longitude',
    );
    if (safeNotes.isNotEmpty) {
      buffer.writeln('Notes: $safeNotes');
    }
    buffer.writeln('Time: ${DateTime.now().toIso8601String()}');
    return buffer.toString().trim();
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
      'backendResponse': result.backendResponse,
    });
  }
}
