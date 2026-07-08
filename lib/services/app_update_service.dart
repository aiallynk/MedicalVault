import 'dart:io';

import 'package:android_package_installer/android_package_installer.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_service.dart';

final RegExp _sha256HexPattern = RegExp(r'^[a-f0-9]{64}$');

String _normalizeSha256Hex(Object? value) =>
    (value ?? '').toString().trim().toLowerCase();

bool _isValidSha256Hex(String value) => _sha256HexPattern.hasMatch(value);

@immutable
class AppUpdateInfo {
  final String latestVersion;
  final String minimumSupportedVersion;
  final String apkUrl;
  final String releaseNotes;
  final String sha256;
  final bool hasUpdate;
  final bool forceUpdate;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.minimumSupportedVersion,
    required this.apkUrl,
    required this.releaseNotes,
    required this.sha256,
    required this.hasUpdate,
    required this.forceUpdate,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersion:
          (json['latestVersion'] ?? json['version'] ?? '').toString().trim(),
      minimumSupportedVersion:
          (json['minimumSupportedVersion'] ?? '').toString().trim(),
      apkUrl: (json['apkUrl'] ?? '').toString().trim(),
      releaseNotes: (json['releaseNotes'] ?? '').toString().trim(),
      sha256: _normalizeSha256Hex(json['sha256'] ?? json['checksum']),
      hasUpdate: json['hasUpdate'] == true,
      forceUpdate: json['forceUpdate'] == true,
    );
  }
}

@immutable
class AppUpdateCheckResult {
  final String currentVersion;
  final AppUpdateInfo? info;
  final bool hasUpdate;
  final bool forceUpdate;
  final bool shouldPrompt;
  final bool skippedByUser;
  final String? error;

  const AppUpdateCheckResult({
    required this.currentVersion,
    this.info,
    required this.hasUpdate,
    required this.forceUpdate,
    required this.shouldPrompt,
    required this.skippedByUser,
    this.error,
  });
}

enum AppUpdateInstallState {
  launchedInstaller,
  notSupported,
  metadataInvalid,
  apkMissing,
  downloadFailed,
  checksumMismatch,
  permissionDenied,
  installerUnavailable,
  installFailed,
}

enum AppUpdateDownloadState {
  downloaded,
  notSupported,
  metadataInvalid,
  apkMissing,
  downloadFailed,
  checksumMismatch,
}

@immutable
class AppUpdateDownloadResult {
  final AppUpdateDownloadState state;
  final String message;
  final String? apkPath;
  final bool checksumVerified;
  final bool reusedCachedApk;

  const AppUpdateDownloadResult({
    required this.state,
    required this.message,
    this.apkPath,
    this.checksumVerified = false,
    this.reusedCachedApk = false,
  });

  bool get isReady =>
      state == AppUpdateDownloadState.downloaded &&
      checksumVerified &&
      apkPath != null &&
      apkPath!.trim().isNotEmpty;
}

@immutable
class AppUpdatePendingInstall {
  final String targetVersion;
  final String apkPath;
  final String sha256;
  final int startedAtMs;

  const AppUpdatePendingInstall({
    required this.targetVersion,
    required this.apkPath,
    required this.sha256,
    required this.startedAtMs,
  });
}

@immutable
class AppUpdateInstallResult {
  final AppUpdateInstallState state;
  final String message;
  final PackageInstallerStatus? installerStatus;
  final bool checksumVerified;

  const AppUpdateInstallResult({
    required this.state,
    required this.message,
    this.installerStatus,
    this.checksumVerified = false,
  });

  bool get isSuccess => state == AppUpdateInstallState.launchedInstaller;
  bool get installCompleted =>
      installerStatus == PackageInstallerStatus.success;
  bool get installerPromptShown =>
      installerStatus == PackageInstallerStatus.pendingUserAction;
}

class AppUpdateService {
  static const String skipVersionKey = 'update_skip_version';
  static const String skipUntilMsKey = 'update_skip_until_ms';
  static const String pendingInstallVersionKey = 'update_pending_version';
  static const String pendingInstallApkPathKey = 'update_pending_apk_path';
  static const String pendingInstallSha256Key = 'update_pending_sha256';
  static const String pendingInstallStartedMsKey = 'update_pending_started_ms';
  static const Duration skipWindow = Duration(hours: 24);

  final Dio _dio;

  AppUpdateService({Dio? dio}) : _dio = dio ?? Dio();

  String _withVersionQuery(String rawUrl, String version,
      {bool addNonce = false}) {
    final base = rawUrl.trim();
    if (base.isEmpty) return base;
    final uri = Uri.parse(base);
    final params = Map<String, String>.from(uri.queryParameters);
    params['v'] = version.trim();
    if (addNonce) {
      params['ts'] = DateTime.now().millisecondsSinceEpoch.toString();
    }
    return uri.replace(queryParameters: params).toString();
  }

  Future<String> getInstalledVersion() async {
    final package = await PackageInfo.fromPlatform();
    return package.version.trim();
  }

  Future<PackageInfo> getPackageInfo() {
    return PackageInfo.fromPlatform();
  }

  Future<AppUpdateInfo> fetchUpdateInfo({String? currentVersion}) async {
    final version = (currentVersion == null || currentVersion.trim().isEmpty)
        ? await getInstalledVersion()
        : currentVersion.trim();

    final response = await _dio.get<Map<String, dynamic>>(
      '${ApiService.baseUrl}/app/update',
      queryParameters: {'currentVersion': version},
      options: Options(
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
      ),
    );

    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty update response');
    }

    final info = AppUpdateInfo.fromJson(data);
    if (info.latestVersion.isEmpty || info.minimumSupportedVersion.isEmpty) {
      throw const FormatException('Update metadata invalid');
    }
    if (info.sha256.isEmpty) {
      throw const FormatException(
          'Update metadata invalid: SHA256 is missing.');
    }
    if (!_isValidSha256Hex(info.sha256)) {
      throw const FormatException(
        'Update metadata invalid: SHA256 must be a 64-character hex value.',
      );
    }

    if (info.apkUrl.isNotEmpty) {
      final normalized = AppUpdateInfo(
        latestVersion: info.latestVersion,
        minimumSupportedVersion: info.minimumSupportedVersion,
        apkUrl: _withVersionQuery(info.apkUrl, info.latestVersion),
        releaseNotes: info.releaseNotes,
        sha256: info.sha256,
        hasUpdate: info.hasUpdate,
        forceUpdate: info.forceUpdate,
      );
      await _clearStaleSkipData(normalized.latestVersion);
      return normalized;
    }

    // Backward-compatible fallback for deployments that return an empty apkUrl.
    final fallback = AppUpdateInfo(
      latestVersion: info.latestVersion,
      minimumSupportedVersion: info.minimumSupportedVersion,
      apkUrl: _withVersionQuery(
        '${ApiService.baseUrl}/app/apk/${info.latestVersion}',
        info.latestVersion,
      ),
      releaseNotes: info.releaseNotes,
      sha256: info.sha256,
      hasUpdate: info.hasUpdate,
      forceUpdate: info.forceUpdate,
    );
    await _clearStaleSkipData(fallback.latestVersion);
    return fallback;
  }

  Future<AppUpdateCheckResult> checkForUpdate({
    bool ignoreSkipWindow = false,
  }) async {
    final currentVersion = await getInstalledVersion();
    try {
      final info = await fetchUpdateInfo(currentVersion: currentVersion);
      final hasUpdateFromVersion =
          compareVersions(currentVersion, info.latestVersion) < 0;
      final forceUpdateFromVersion =
          compareVersions(currentVersion, info.minimumSupportedVersion) < 0;

      // Prefer deterministic client-side version comparison so splash checks
      // still work even if backend flags are missing/outdated.
      final hasUpdate = hasUpdateFromVersion || info.hasUpdate;
      final forceUpdate = forceUpdateFromVersion || info.forceUpdate;

      if (!hasUpdate) {
        return AppUpdateCheckResult(
          currentVersion: currentVersion,
          info: info,
          hasUpdate: false,
          forceUpdate: false,
          shouldPrompt: false,
          skippedByUser: false,
        );
      }

      if (forceUpdate) {
        return AppUpdateCheckResult(
          currentVersion: currentVersion,
          info: info,
          hasUpdate: true,
          forceUpdate: true,
          shouldPrompt: true,
          skippedByUser: false,
        );
      }

      final skipped = ignoreSkipWindow
          ? false
          : await _shouldSkipVersion(info.latestVersion);
      return AppUpdateCheckResult(
        currentVersion: currentVersion,
        info: info,
        hasUpdate: true,
        forceUpdate: false,
        shouldPrompt: !skipped,
        skippedByUser: skipped,
      );
    } catch (error) {
      debugPrint('Update check failed: $error');
      return AppUpdateCheckResult(
        currentVersion: currentVersion,
        hasUpdate: false,
        forceUpdate: false,
        shouldPrompt: false,
        skippedByUser: false,
        error: _friendlyCheckError(error),
      );
    }
  }

  Future<void> skipVersionFor24Hours(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now().add(skipWindow).millisecondsSinceEpoch;
    await prefs.setString(skipVersionKey, version);
    await prefs.setInt(skipUntilMsKey, until);
  }

  Future<void> clearSkipWindow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(skipVersionKey);
    await prefs.remove(skipUntilMsKey);
  }

  Future<bool> _shouldSkipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final skippedVersion = prefs.getString(skipVersionKey);
    final skipUntilMs = prefs.getInt(skipUntilMsKey);
    if (skippedVersion == null || skipUntilMs == null) return false;
    if (skippedVersion != version) return false;

    final isActive = DateTime.now().millisecondsSinceEpoch < skipUntilMs;
    if (!isActive) {
      await clearSkipWindow();
    }
    return isActive;
  }

  static int compareVersions(String left, String right) {
    final leftParts = _parseVersion(left);
    final rightParts = _parseVersion(right);
    final maxLen = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (int index = 0; index < maxLen; index++) {
      final a = index < leftParts.length ? leftParts[index] : 0;
      final b = index < rightParts.length ? rightParts[index] : 0;
      if (a > b) return 1;
      if (a < b) return -1;
    }
    return 0;
  }

  static List<int> _parseVersion(String value) {
    return value.trim().split('.').where((part) => part.isNotEmpty).map((part) {
      final match = RegExp(r'\d+').firstMatch(part);
      if (match == null) return 0;
      return int.tryParse(match.group(0) ?? '0') ?? 0;
    }).toList();
  }

  Future<AppUpdateDownloadResult> downloadAndVerifyUpdate({
    required AppUpdateInfo info,
    ValueChanged<double>? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      return const AppUpdateDownloadResult(
        state: AppUpdateDownloadState.notSupported,
        message: 'APK updates are only supported on Android devices.',
      );
    }

    final apkTargetPath = await _buildApkTargetPath(info.latestVersion);
    bool checksumVerified = false;
    final expectedChecksum = info.sha256.trim().toLowerCase();
    if (expectedChecksum.isEmpty || !_isValidSha256Hex(expectedChecksum)) {
      return const AppUpdateDownloadResult(
        state: AppUpdateDownloadState.metadataInvalid,
        message: 'Update metadata invalid.',
      );
    }

    final cachedFile = File(apkTargetPath);
    if (await cachedFile.exists()) {
      final cachedChecksum = await _computeChecksum(apkTargetPath);
      if (cachedChecksum == expectedChecksum) {
        onProgress?.call(1);
        await _clearCachedApkArtifacts(keepTargetPath: apkTargetPath);
        return AppUpdateDownloadResult(
          state: AppUpdateDownloadState.downloaded,
          message: 'Update downloaded and verified. Ready to install.',
          apkPath: apkTargetPath,
          checksumVerified: true,
          reusedCachedApk: true,
        );
      }
      try {
        await cachedFile.delete();
      } catch (_) {}
    }

    await _clearCachedApkArtifacts(keepTargetPath: apkTargetPath);

    for (int attempt = 0; attempt < 2; attempt++) {
      final shouldAddNonce = attempt > 0;
      final downloadUrl = _withVersionQuery(
        info.apkUrl,
        info.latestVersion,
        addNonce: shouldAddNonce,
      );

      try {
        await _dio.download(
          downloadUrl,
          apkTargetPath,
          onReceiveProgress: (received, total) {
            if (total <= 0) return;
            onProgress?.call(received / total);
          },
          options: Options(
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(minutes: 10),
            headers: const {
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
          ),
        );
      } on DioException catch (error) {
        debugPrint('Update download failed: ${error.type}');
        final status = error.response?.statusCode;
        if (status == 404) {
          return const AppUpdateDownloadResult(
            state: AppUpdateDownloadState.apkMissing,
            message: 'APK file missing on server.',
          );
        }
        final serverMessage = _extractResponseMessage(error.response?.data);
        return AppUpdateDownloadResult(
          state: AppUpdateDownloadState.downloadFailed,
          message: serverMessage.trim().isNotEmpty
              ? serverMessage
              : 'Failed to download update. Please check your connection.',
        );
      } catch (_) {
        return const AppUpdateDownloadResult(
          state: AppUpdateDownloadState.downloadFailed,
          message: 'Failed to download update. Please check your connection.',
        );
      }

      final actualChecksum = await _computeChecksum(apkTargetPath);
      debugPrint('APK checksum verification attempt ${attempt + 1}');

      final isValid = actualChecksum == expectedChecksum;
      if (isValid) {
        checksumVerified = true;
        break;
      }

      if (attempt == 0) {
        try {
          final stale = File(apkTargetPath);
          if (await stale.exists()) {
            await stale.delete();
          }
        } catch (_) {
          // Continue with retry even if file deletion fails.
        }
        continue;
      }

      return const AppUpdateDownloadResult(
        state: AppUpdateDownloadState.checksumMismatch,
        message: 'Downloaded APK checksum mismatch.',
      );
    }

    return AppUpdateDownloadResult(
      state: AppUpdateDownloadState.downloaded,
      message: 'Update downloaded and verified. Ready to install.',
      apkPath: apkTargetPath,
      checksumVerified: checksumVerified,
    );
  }

  Future<AppUpdateInstallResult> launchInstallUpdate({
    required AppUpdateInfo info,
    required String apkPath,
  }) async {
    if (!Platform.isAndroid) {
      return const AppUpdateInstallResult(
        state: AppUpdateInstallState.notSupported,
        message: 'APK updates are only supported on Android devices.',
      );
    }

    final expectedChecksum = info.sha256.trim().toLowerCase();
    if (expectedChecksum.isEmpty || !_isValidSha256Hex(expectedChecksum)) {
      return const AppUpdateInstallResult(
        state: AppUpdateInstallState.metadataInvalid,
        message: 'Update metadata invalid.',
      );
    }

    final file = File(apkPath);
    if (!await file.exists()) {
      return const AppUpdateInstallResult(
        state: AppUpdateInstallState.apkMissing,
        message: 'Downloaded APK is missing. Please download again.',
      );
    }

    final actualChecksum = await _computeChecksum(apkPath);
    if (actualChecksum != expectedChecksum) {
      try {
        await file.delete();
      } catch (_) {}
      return const AppUpdateInstallResult(
        state: AppUpdateInstallState.checksumMismatch,
        message: 'Downloaded APK checksum mismatch. Please download again.',
      );
    }

    final installPermission = await Permission.requestInstallPackages.status;
    if (!installPermission.isGranted) {
      final requestedPermission =
          await Permission.requestInstallPackages.request();
      if (!requestedPermission.isGranted) {
        return const AppUpdateInstallResult(
          state: AppUpdateInstallState.permissionDenied,
          message: 'Install permission not granted.',
        );
      }
    }

    await persistPendingInstall(
      targetVersion: info.latestVersion,
      apkPath: apkPath,
      sha256: expectedChecksum,
    );

    final int? code;
    try {
      code = await AndroidPackageInstaller.installApk(apkFilePath: apkPath);
    } catch (error) {
      debugPrint('Unable to launch installer: $error');
      return const AppUpdateInstallResult(
        state: AppUpdateInstallState.installerUnavailable,
        message: 'Unable to open installer. Please try again.',
      );
    }

    if (code == null) {
      return const AppUpdateInstallResult(
        state: AppUpdateInstallState.installFailed,
        message: 'Installer returned no status.',
      );
    }

    final installerStatus = PackageInstallerStatus.byCode(code);
    if (installerStatus == PackageInstallerStatus.success ||
        installerStatus == PackageInstallerStatus.pendingUserAction) {
      return AppUpdateInstallResult(
        state: AppUpdateInstallState.launchedInstaller,
        message: _statusMessage(installerStatus),
        installerStatus: installerStatus,
        checksumVerified: true,
      );
    }

    return AppUpdateInstallResult(
      state: AppUpdateInstallState.installFailed,
      message: _statusMessage(installerStatus),
      installerStatus: installerStatus,
      checksumVerified: true,
    );
  }

  Future<AppUpdateInstallResult> downloadAndInstallUpdate({
    required AppUpdateInfo info,
    ValueChanged<double>? onProgress,
  }) async {
    final downloadResult = await downloadAndVerifyUpdate(
      info: info,
      onProgress: onProgress,
    );
    if (!downloadResult.isReady) {
      final state = switch (downloadResult.state) {
        AppUpdateDownloadState.notSupported =>
          AppUpdateInstallState.notSupported,
        AppUpdateDownloadState.metadataInvalid =>
          AppUpdateInstallState.metadataInvalid,
        AppUpdateDownloadState.apkMissing => AppUpdateInstallState.apkMissing,
        AppUpdateDownloadState.downloadFailed =>
          AppUpdateInstallState.downloadFailed,
        AppUpdateDownloadState.checksumMismatch =>
          AppUpdateInstallState.checksumMismatch,
        AppUpdateDownloadState.downloaded =>
          AppUpdateInstallState.downloadFailed,
      };
      return AppUpdateInstallResult(
        state: state,
        message: downloadResult.message,
        checksumVerified: downloadResult.checksumVerified,
      );
    }
    return launchInstallUpdate(info: info, apkPath: downloadResult.apkPath!);
  }

  Future<void> persistPendingInstall({
    required String targetVersion,
    required String apkPath,
    required String sha256,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingInstallVersionKey, targetVersion);
    await prefs.setString(pendingInstallApkPathKey, apkPath);
    await prefs.setString(pendingInstallSha256Key, sha256);
    await prefs.setInt(
      pendingInstallStartedMsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<AppUpdatePendingInstall?> getPendingInstall() async {
    final prefs = await SharedPreferences.getInstance();
    final targetVersion = prefs.getString(pendingInstallVersionKey)?.trim();
    final apkPath = prefs.getString(pendingInstallApkPathKey)?.trim();
    final sha256 = prefs.getString(pendingInstallSha256Key)?.trim();
    final startedAtMs = prefs.getInt(pendingInstallStartedMsKey);
    if (targetVersion == null ||
        targetVersion.isEmpty ||
        apkPath == null ||
        apkPath.isEmpty ||
        sha256 == null ||
        sha256.isEmpty ||
        startedAtMs == null) {
      return null;
    }
    return AppUpdatePendingInstall(
      targetVersion: targetVersion,
      apkPath: apkPath,
      sha256: sha256,
      startedAtMs: startedAtMs,
    );
  }

  Future<void> clearPendingInstall() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingInstallVersionKey);
    await prefs.remove(pendingInstallApkPathKey);
    await prefs.remove(pendingInstallSha256Key);
    await prefs.remove(pendingInstallStartedMsKey);
  }

  Future<bool> isPendingInstallSatisfied([
    AppUpdatePendingInstall? pending,
  ]) async {
    final candidate = pending ?? await getPendingInstall();
    if (candidate == null) return false;
    final installedVersion = await getInstalledVersion();
    final satisfied =
        compareVersions(installedVersion, candidate.targetVersion) >= 0;
    if (satisfied) {
      await clearPendingInstall();
      await clearSkipWindow();
    }
    return satisfied;
  }

  Future<bool> isPendingApkReusable(AppUpdatePendingInstall pending) async {
    final file = File(pending.apkPath);
    if (!await file.exists()) return false;
    final checksum = await _computeChecksum(pending.apkPath);
    return checksum == pending.sha256.toLowerCase();
  }

  Future<String> _buildApkTargetPath(String version) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = 'medical_vault_update_${version.replaceAll('.', '_')}.apk';
    return path.join(tempDir.path, fileName);
  }

  Future<void> _clearCachedApkArtifacts(
      {required String keepTargetPath}) async {
    final tempDir = await getTemporaryDirectory();
    final keep = path.normalize(keepTargetPath);
    final entities = tempDir.listSync();
    for (final entity in entities) {
      if (entity is! File) continue;
      final fileName = path.basename(entity.path).toLowerCase();
      if (!fileName.startsWith('medical_vault_update_') ||
          !fileName.endsWith('.apk')) {
        continue;
      }
      final normalized = path.normalize(entity.path);
      if (normalized == keep) {
        continue;
      }
      try {
        if (await entity.exists()) {
          await entity.delete();
        }
      } catch (_) {
        // Ignore cache cleanup errors.
      }
    }
  }

  Future<void> _clearStaleSkipData(String latestVersion) async {
    final prefs = await SharedPreferences.getInstance();
    final skippedVersion = prefs.getString(skipVersionKey)?.trim();
    if (skippedVersion == null || skippedVersion.isEmpty) return;
    if (skippedVersion == latestVersion) return;
    if (skippedVersion == '1.0.8' ||
        compareVersions(skippedVersion, latestVersion) < 0) {
      await clearSkipWindow();
    }
  }

  Future<String?> _computeChecksum(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return crypto.sha256.convert(bytes).toString().toLowerCase();
  }

  String _statusMessage(PackageInstallerStatus status) {
    switch (status) {
      case PackageInstallerStatus.pendingUserAction:
        return 'Installer launched. Confirm the install prompt to continue.';
      case PackageInstallerStatus.success:
        return 'Installation completed successfully.';
      case PackageInstallerStatus.failure:
        return 'Installation failed.';
      case PackageInstallerStatus.failureBlocked:
        return 'Installation blocked by system policy.';
      case PackageInstallerStatus.failureAborted:
        return 'Installation was cancelled.';
      case PackageInstallerStatus.failureInvalid:
        return 'Invalid APK package. If checksum passed, verify the APK is signed with the same production keystore as the installed app.';
      case PackageInstallerStatus.failureConflict:
        return 'APK signature differs from installed app or package conflicts. Install a build signed with the same production keystore.';
      case PackageInstallerStatus.failureStorage:
        return 'Insufficient storage for update.';
      case PackageInstallerStatus.failureIncompatible:
        return 'APK is incompatible with this device.';
      case PackageInstallerStatus.unknown:
        return 'Unknown installer status.';
    }
  }

  String _friendlyCheckError(Object error) {
    if (error is FormatException) {
      return error.message.trim().isNotEmpty
          ? error.message
          : 'Update metadata invalid.';
    }
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null) {
        return 'Update server returned $statusCode. Please try again shortly.';
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Update check timed out. Please try again.';
        case DioExceptionType.connectionError:
          return 'No internet connection. Please check your network.';
        case DioExceptionType.cancel:
          return 'Update check was cancelled.';
        case DioExceptionType.badCertificate:
        case DioExceptionType.badResponse:
        case DioExceptionType.unknown:
          return 'Unable to check for updates right now.';
        // Newer dio versions add enum values (e.g. transformTimeout); keep this
        // resilient to future additions.
        default:
          return 'Unable to check for updates right now.';
      }
    }
    return 'Unable to check for updates right now.';
  }

  String _extractResponseMessage(dynamic raw) {
    Map<String, dynamic> payload = const <String, dynamic>{};
    if (raw is Map<String, dynamic>) {
      payload = raw;
    } else if (raw is Map) {
      payload = raw.map((key, value) => MapEntry(key.toString(), value));
    }

    for (final key in const ['message', 'msg', 'error']) {
      final value = payload[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    final nested = payload['data'];
    if (nested is Map) {
      for (final key in const ['message', 'msg', 'error']) {
        final value = nested[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return '';
  }
}
