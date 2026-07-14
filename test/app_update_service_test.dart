import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hello/services/app_update_service.dart';

/// A minimal fake [HttpClientAdapter] that returns a fixed JSON body and
/// status code for every request, regardless of the URL/query string. This
/// lets tests drive AppUpdateService.checkForUpdate() end-to-end (including
/// its real HTTP call path) without touching the network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.statusCode, this.jsonBody);

  final int statusCode;
  final Map<String, dynamic> jsonBody;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(jsonBody),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Dio _dioReturning(int statusCode, Map<String, dynamic> jsonBody) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example-backend.test/api'));
  dio.httpClientAdapter = _FakeAdapter(statusCode, jsonBody);
  return dio;
}

const String _kFakeSha256 =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Map<String, dynamic> _serverConfig({
  required String latestVersion,
  int? latestBuildNumber,
  required String minimumSupportedVersion,
  int? minimumSupportedBuildNumber,
  String apkUrl = 'https://example-backend.test/api/v1/app/apk/1.0.24',
  String sha256 = _kFakeSha256,
  bool hasUpdate = true,
  bool forceUpdate = false,
}) {
  return {
    'latestVersion': latestVersion,
    if (latestBuildNumber != null) 'latestBuildNumber': latestBuildNumber,
    'minimumSupportedVersion': minimumSupportedVersion,
    if (minimumSupportedBuildNumber != null)
      'minimumSupportedBuildNumber': minimumSupportedBuildNumber,
    'apkUrl': apkUrl,
    'apkFileName': '$latestVersion.apk',
    'releaseNotes': 'Test release notes',
    'sha256': sha256,
    'checksum': sha256,
    'hasUpdate': hasUpdate,
    'forceUpdate': forceUpdate,
  };
}

void setInstalled({required String version, required String buildNumber}) {
  PackageInfo.setMockInitialValues(
    appName: 'Medical Vault',
    packageName: 'com.example.hello',
    version: version,
    buildNumber: buildNumber,
    buildSignature: '',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // ApiService.baseUrl reads from dotenv; AppUpdateService.fetchUpdateInfo
    // builds its request URL against it, so it must be initialized even
    // though the fake Dio adapter ignores the actual URL/host.
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://example-backend.test/api',
    );
  });

  group('AppUpdateService.compareVersions (pure)', () {
    test('numeric comparison, not lexicographic', () {
      expect(AppUpdateService.compareVersions('1.0.9', '1.0.10'), lessThan(0));
      expect(AppUpdateService.compareVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(AppUpdateService.compareVersions('1.0.0', '1.0.0'), 0);
    });
  });

  group('AppUpdateInfo.fromJson', () {
    test('parses additive build-number fields when present', () {
      final info = AppUpdateInfo.fromJson(_serverConfig(
        latestVersion: '1.0.24',
        latestBuildNumber: 24,
        minimumSupportedVersion: '1.0.18',
        minimumSupportedBuildNumber: 18,
      ));
      expect(info.latestBuildNumber, 24);
      expect(info.minimumSupportedBuildNumber, 18);
    });

    test('build-number fields are null when absent (legacy backend response)', () {
      final legacyJson = {
        'latestVersion': '1.0.23',
        'minimumSupportedVersion': '1.0.18',
        'apkUrl': 'https://example-backend.test/api/v1/app/apk/1.0.23',
        'releaseNotes': 'legacy',
        'sha256': 'a' * 64,
        'checksum': 'a' * 64,
        'hasUpdate': true,
        'forceUpdate': false,
      };
      final info = AppUpdateInfo.fromJson(legacyJson);
      expect(info.latestBuildNumber, isNull);
      expect(info.minimumSupportedBuildNumber, isNull);
      expect(info.latestVersion, '1.0.23');
    });

    test('ignores malformed non-numeric build-number fields', () {
      final json = _serverConfig(
        latestVersion: '1.0.24',
        minimumSupportedVersion: '1.0.18',
      );
      json['latestBuildNumber'] = 'not-a-number';
      final info = AppUpdateInfo.fromJson(json);
      expect(info.latestBuildNumber, isNull);
    });
  });

  group('AppUpdateService.checkForUpdate — version/build trace cases', () {
    test('older installed version receives an update', () async {
      setInstalled(version: '1.0.20', buildNumber: '20');
      final service = AppUpdateService(
        dio: _dioReturning(200, _serverConfig(
          latestVersion: '1.0.24',
          latestBuildNumber: 24,
          minimumSupportedVersion: '1.0.18',
          minimumSupportedBuildNumber: 18,
        )),
      );
      final result = await service.checkForUpdate(ignoreSkipWindow: true);
      expect(result.hasUpdate, isTrue);
      expect(result.forceUpdate, isFalse);
    });

    test(
        'same version, lower installed build number (1.0.23+22 vs latestBuildNumber 23) receives an update',
        () async {
      setInstalled(version: '1.0.23', buildNumber: '22');
      final service = AppUpdateService(
        dio: _dioReturning(200, _serverConfig(
          latestVersion: '1.0.23',
          latestBuildNumber: 23,
          minimumSupportedVersion: '1.0.18',
          minimumSupportedBuildNumber: 18,
        )),
      );
      final result = await service.checkForUpdate(ignoreSkipWindow: true);
      expect(result.hasUpdate, isTrue);
      expect(result.forceUpdate, isFalse);
    });

    test('current version/build exactly matches latest: no update', () async {
      setInstalled(version: '1.0.24', buildNumber: '24');
      final service = AppUpdateService(
        dio: _dioReturning(
          200,
          _serverConfig(
            latestVersion: '1.0.24',
            latestBuildNumber: 24,
            minimumSupportedVersion: '1.0.18',
            minimumSupportedBuildNumber: 18,
            hasUpdate: false,
          ),
        ),
      );
      final result = await service.checkForUpdate(ignoreSkipWindow: true);
      expect(result.hasUpdate, isFalse);
      expect(result.forceUpdate, isFalse);
    });

    test(
        'newer installed version than server latest (1.0.24+24 vs latest 1.0.23+23): never downgrade',
        () async {
      setInstalled(version: '1.0.24', buildNumber: '24');
      final service = AppUpdateService(
        dio: _dioReturning(
          200,
          _serverConfig(
            latestVersion: '1.0.23',
            latestBuildNumber: 23,
            minimumSupportedVersion: '1.0.18',
            minimumSupportedBuildNumber: 18,
            // Simulate a stale/misconfigured server flag to prove the
            // client-side guard against downgrade wins regardless.
            hasUpdate: true,
          ),
        ),
      );
      final result = await service.checkForUpdate(ignoreSkipWindow: true);
      expect(result.hasUpdate, isFalse);
      expect(result.forceUpdate, isFalse);
    });

    test('below minimum version forces update (1.0.17+17 vs minimum 1.0.18+18)', () async {
      setInstalled(version: '1.0.17', buildNumber: '17');
      final service = AppUpdateService(
        dio: _dioReturning(200, _serverConfig(
          latestVersion: '1.0.24',
          latestBuildNumber: 24,
          minimumSupportedVersion: '1.0.18',
          minimumSupportedBuildNumber: 18,
        )),
      );
      final result = await service.checkForUpdate(ignoreSkipWindow: true);
      expect(result.hasUpdate, isTrue);
      expect(result.forceUpdate, isTrue);
    });

    test('same version as minimum, but lower build number, forces update', () async {
      setInstalled(version: '1.0.18', buildNumber: '17');
      final service = AppUpdateService(
        dio: _dioReturning(200, _serverConfig(
          latestVersion: '1.0.24',
          latestBuildNumber: 24,
          minimumSupportedVersion: '1.0.18',
          minimumSupportedBuildNumber: 18,
        )),
      );
      final result = await service.checkForUpdate(ignoreSkipWindow: true);
      expect(result.hasUpdate, isTrue);
      expect(result.forceUpdate, isTrue);
    });

    test('old server response without build-number fields still works (backward compatible)', () async {
      setInstalled(version: '1.0.20', buildNumber: '20');
      final legacyJson = {
        'latestVersion': '1.0.23',
        'minimumSupportedVersion': '1.0.18',
        'apkUrl': 'https://example-backend.test/api/v1/app/apk/1.0.23',
        'releaseNotes': 'legacy',
        'sha256': 'a' * 64,
        'checksum': 'a' * 64,
        'hasUpdate': true,
        'forceUpdate': false,
      };
      final service = AppUpdateService(dio: _dioReturning(200, legacyJson));
      final result = await service.checkForUpdate(ignoreSkipWindow: true);
      expect(result.hasUpdate, isTrue);
      expect(result.forceUpdate, isFalse);
      expect(result.info?.latestBuildNumber, isNull);
    });

    test('invalid response (missing sha256) surfaces a real error, not "no update"', () async {
      setInstalled(version: '1.0.20', buildNumber: '20');
      final invalidJson = {
        'latestVersion': '1.0.24',
        'minimumSupportedVersion': '1.0.18',
        'apkUrl': 'https://example-backend.test/api/v1/app/apk/1.0.24',
        'releaseNotes': '',
        'sha256': '',
        'checksum': '',
        'hasUpdate': true,
        'forceUpdate': false,
      };
      final service = AppUpdateService(dio: _dioReturning(200, invalidJson));
      final result = await service.checkForUpdate(ignoreSkipWindow: true);
      expect(result.hasUpdate, isFalse);
      expect(result.error, isNotNull);
      expect(result.error, isNot(contains('no update')));
    });

    test('empty apkUrl falls back to constructed download URL (backward-compatible contract)', () async {
      setInstalled(version: '1.0.20', buildNumber: '20');
      final json = _serverConfig(
        latestVersion: '1.0.24',
        latestBuildNumber: 24,
        minimumSupportedVersion: '1.0.18',
        minimumSupportedBuildNumber: 18,
        apkUrl: '',
      );
      final service = AppUpdateService(dio: _dioReturning(200, json));
      final result = await service.checkForUpdate(ignoreSkipWindow: true);
      expect(result.info?.apkUrl, isNotEmpty);
      expect(result.info?.apkUrl, contains('/app/apk/1.0.24'));
    });

    test('skip-state does not suppress a forced update', () async {
      setInstalled(version: '1.0.17', buildNumber: '17');
      final service = AppUpdateService(
        dio: _dioReturning(200, _serverConfig(
          latestVersion: '1.0.24',
          latestBuildNumber: 24,
          minimumSupportedVersion: '1.0.18',
          minimumSupportedBuildNumber: 18,
        )),
      );
      // Simulate a previously skipped version.
      await service.skipVersionFor24Hours('1.0.24', buildNumber: 24);
      final result = await service.checkForUpdate(ignoreSkipWindow: false);
      expect(result.forceUpdate, isTrue);
      expect(result.shouldPrompt, isTrue);
      expect(result.skippedByUser, isFalse);
    });

    test('skip-state does not hide a newly published build of the same version', () async {
      setInstalled(version: '1.0.23', buildNumber: '22');
      final service = AppUpdateService(
        dio: _dioReturning(200, _serverConfig(
          latestVersion: '1.0.23',
          latestBuildNumber: 23,
          minimumSupportedVersion: '1.0.18',
          minimumSupportedBuildNumber: 18,
        )),
      );
      // User previously skipped 1.0.23 build 22 (an earlier server state).
      await service.skipVersionFor24Hours('1.0.23', buildNumber: 22);
      final result = await service.checkForUpdate(ignoreSkipWindow: false);
      // The server now advertises build 23 for the same version — the old
      // skip (keyed to build 22) must not suppress this newer build.
      expect(result.hasUpdate, isTrue);
      expect(result.shouldPrompt, isTrue);
      expect(result.skippedByUser, isFalse);
    });

    test('skip-state suppresses prompt for the exact version+build the user skipped', () async {
      setInstalled(version: '1.0.20', buildNumber: '20');
      final service = AppUpdateService(
        dio: _dioReturning(200, _serverConfig(
          latestVersion: '1.0.24',
          latestBuildNumber: 24,
          minimumSupportedVersion: '1.0.18',
          minimumSupportedBuildNumber: 18,
        )),
      );
      await service.skipVersionFor24Hours('1.0.24', buildNumber: 24);
      final result = await service.checkForUpdate(ignoreSkipWindow: false);
      expect(result.hasUpdate, isTrue);
      expect(result.shouldPrompt, isFalse);
      expect(result.skippedByUser, isTrue);
    });
  });

  group('AppUpdateService.checkForUpdate — network/error resilience', () {
    test('non-200 response does not crash and surfaces as no-update with error', () async {
      setInstalled(version: '1.0.20', buildNumber: '20');
      final dio = Dio(BaseOptions(baseUrl: 'https://example-backend.test/api'));
      dio.httpClientAdapter = _FakeAdapter(500, {'message': 'server error'});
      final service = AppUpdateService(dio: dio);
      final result = await service.checkForUpdate(ignoreSkipWindow: true);
      expect(result.hasUpdate, isFalse);
      expect(result.error, isNotNull);
    });
  });
}
