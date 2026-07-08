import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

@immutable
class EmergencySmsResult {
  const EmergencySmsResult({
    required this.success,
    required this.recipient,
    this.errorCode,
    this.errorMessage,
  });

  final bool success;
  final String recipient;
  final String? errorCode;
  final String? errorMessage;

  factory EmergencySmsResult.fromJson(Map<dynamic, dynamic> json) {
    return EmergencySmsResult(
      success: json['success'] == true,
      recipient: (json['recipient'] ?? '').toString(),
      errorCode: json['errorCode']?.toString(),
      errorMessage: json['errorMessage']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        'recipient': recipient,
        if (errorCode != null) 'errorCode': errorCode,
        if (errorMessage != null) 'errorMessage': errorMessage,
      };
}

class SosSmsService {
  SosSmsService._internal();
  static final SosSmsService instance = SosSmsService._internal();

  static const MethodChannel _channel = MethodChannel('medical_vault/sos_sms');
  static final RegExp _phonePattern = RegExp(r'^\+?\d{7,15}$');

  String normalizePhone(String value) {
    final compact = value
        .trim()
        .replaceAll(RegExp(r'[\s\-().]'), '')
        .replaceAll(RegExp(r'[^0-9+]'), '');
    if (compact.startsWith('+')) {
      return '+${compact.substring(1).replaceAll('+', '')}';
    }
    return compact.replaceAll('+', '');
  }

  bool isValidPhone(String value) {
    final normalized = normalizePhone(value);
    return _phonePattern.hasMatch(normalized);
  }

  Future<bool> canSendSmsSilently() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('canSendSms') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<PermissionStatus> requestSmsPermissionForSos() async {
    if (!Platform.isAndroid) return PermissionStatus.denied;
    final status = await Permission.sms.status;
    if (status.isGranted) return status;
    return Permission.sms.request();
  }

  Future<EmergencySmsResult> sendEmergencySms({
    required String recipient,
    required String message,
  }) async {
    final normalizedRecipient = normalizePhone(recipient);
    if (!isValidPhone(normalizedRecipient)) {
      return EmergencySmsResult(
        success: false,
        recipient: normalizedRecipient,
        errorCode: 'INVALID_PHONE',
        errorMessage: 'Invalid phone number.',
      );
    }
    if (!Platform.isAndroid) {
      return EmergencySmsResult(
        success: false,
        recipient: normalizedRecipient,
        errorCode: 'UNSUPPORTED_PLATFORM',
        errorMessage: 'Automatic SMS is only supported on Android.',
      );
    }

    try {
      final response = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'sendEmergencySms',
        {
          'recipient': normalizedRecipient,
          'message': message,
        },
      );
      if (response == null) {
        return EmergencySmsResult(
          success: false,
          recipient: normalizedRecipient,
          errorCode: 'NO_NATIVE_RESPONSE',
          errorMessage: 'No SMS status returned.',
        );
      }
      return EmergencySmsResult.fromJson(response);
    } catch (error) {
      return EmergencySmsResult(
        success: false,
        recipient: normalizedRecipient,
        errorCode: 'CHANNEL_ERROR',
        errorMessage: error.toString(),
      );
    }
  }

  Future<bool> openSmsComposer({
    required List<String> recipients,
    required String message,
  }) async {
    final cleanedRecipients = recipients
        .map(normalizePhone)
        .where(isValidPhone)
        .toSet()
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
  }
}
