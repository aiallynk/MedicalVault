import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnvironment {
  const AppEnvironment._();

  static const String _mapsKeyFromDefine = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );
  static const String _legacyMapsKeyFromDefine = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: '',
  );

  static bool _dotenvLoaded = false;

  static Future<void> initialize() async {
    if (_dotenvLoaded) return;
    try {
      await dotenv.load(fileName: '.env', isOptional: true);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Optional .env load skipped: $error');
      }
    } finally {
      _dotenvLoaded = true;
    }
  }

  static String get googleMapsApiKey {
    final defineCandidates = <String>[
      _mapsKeyFromDefine.trim(),
      _legacyMapsKeyFromDefine.trim(),
    ];
    for (final candidate in defineCandidates) {
      if (candidate.isNotEmpty) return candidate;
    }

    final envCandidates = <String>[
      (dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '').trim(),
      (dotenv.env['MAPS_API_KEY'] ?? '').trim(),
    ];
    for (final candidate in envCandidates) {
      if (candidate.isNotEmpty) return candidate;
    }

    return '';
  }

  static bool get hasGoogleMapsApiKey => googleMapsApiKey.isNotEmpty;
}
