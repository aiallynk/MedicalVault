import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnvironment {
  const AppEnvironment._();

  static const String _mapsKeyFromDefine = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
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
    final fromDefine = _mapsKeyFromDefine.trim();
    if (fromDefine.isNotEmpty) return fromDefine;
    return (dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '').trim();
  }

  static bool get hasGoogleMapsApiKey => googleMapsApiKey.isNotEmpty;
}
