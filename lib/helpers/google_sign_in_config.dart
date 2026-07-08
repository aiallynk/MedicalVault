import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';

class GoogleSignInConfig {
  const GoogleSignInConfig({
    required this.packageName,
    required this.buildMode,
    required this.serverClientIdConfigured,
    this.serverClientId,
  });

  static const MethodChannel _channel =
      MethodChannel('medical_vault/google_sign_in_config');

  final String packageName;
  final String buildMode;
  final bool serverClientIdConfigured;
  final String? serverClientId;

  static String get currentBuildMode {
    if (kReleaseMode) return 'release';
    if (kProfileMode) return 'profile';
    return 'debug';
  }

  static Future<GoogleSignInConfig> load() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!Platform.isAndroid) {
      return GoogleSignInConfig(
        packageName: packageInfo.packageName,
        buildMode: currentBuildMode,
        serverClientIdConfigured: false,
      );
    }

    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'getGoogleSignInConfig',
      );
      final webClientId =
          (response?['defaultWebClientId'] ?? '').toString().trim();
      return GoogleSignInConfig(
        packageName:
            (response?['packageName'] ?? packageInfo.packageName).toString(),
        buildMode: currentBuildMode,
        serverClientIdConfigured:
            response?['defaultWebClientIdConfigured'] == true &&
                webClientId.isNotEmpty,
        serverClientId: webClientId.isEmpty ? null : webClientId,
      );
    } catch (error) {
      debugPrint('Google Sign-In config lookup failed: $error');
      return GoogleSignInConfig(
        packageName: packageInfo.packageName,
        buildMode: currentBuildMode,
        serverClientIdConfigured: false,
      );
    }
  }

  void logForSignIn() {
    debugPrint(
      'Google Sign-In Android config: package=$packageName, '
      'buildMode=$buildMode, '
      'serverClientIdConfigured=$serverClientIdConfigured',
    );
  }

  GoogleSignIn createGoogleSignIn({required List<String> scopes}) {
    return GoogleSignIn(
      scopes: scopes,
      serverClientId: serverClientIdConfigured && serverClientId != null
          ? serverClientId
          : null,
    );
  }
}

class GoogleSignInFailure {
  const GoogleSignInFailure({
    required this.userMessage,
    required this.logMessage,
    this.cancelled = false,
  });

  final String userMessage;
  final String logMessage;
  final bool cancelled;

  static GoogleSignInFailure fromError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    final platformCode =
        error is PlatformException ? error.code.toLowerCase() : '';
    final platformMessage =
        error is PlatformException ? (error.message ?? '') : raw;

    if (lower.contains('12501') ||
        lower.contains('sign_in_canceled') ||
        platformCode.contains('canceled') ||
        platformCode.contains('cancelled')) {
      return GoogleSignInFailure(
        userMessage: 'Sign-in cancelled.',
        logMessage: 'Google Sign-In cancelled by user.',
        cancelled: true,
      );
    }

    if (lower.contains('apiexception: 10') ||
        lower.contains('developer_error')) {
      return GoogleSignInFailure(
        userMessage:
            'Google Sign-In configuration error. Please verify Firebase SHA/package settings.',
        logMessage:
            'Google Sign-In DEVELOPER_ERROR. Verify Firebase Android package, SHA-1/SHA-256, and OAuth clients. Raw: $platformMessage',
      );
    }

    if (lower.contains('apiexception: 7') ||
        lower.contains('network_error') ||
        platformCode.contains('network') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup')) {
      return GoogleSignInFailure(
        userMessage:
            'Network error during Google Sign-In. Please check your connection and try again.',
        logMessage: 'Google Sign-In network error. Raw: $platformMessage',
      );
    }

    return GoogleSignInFailure(
      userMessage: 'Google Sign-In failed. Please try again.',
      logMessage: 'Google Sign-In failed. Raw: $platformMessage',
    );
  }
}
