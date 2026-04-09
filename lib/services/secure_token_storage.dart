import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureTokenStorage {
  static const String _tokenKey = 'authToken';
  static const String _refreshTokenKey = 'authRefreshToken';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static Future<void> saveToken(String token) async {
    if (token.trim().isEmpty) return;
    await _secureStorage.write(key: _tokenKey, value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<void> saveRefreshToken(String refreshToken) async {
    if (refreshToken.trim().isEmpty) return;
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_refreshTokenKey);
  }

  static Future<String?> getToken() async {
    final secureToken = await _secureStorage.read(key: _tokenKey);
    if (secureToken != null && secureToken.trim().isNotEmpty) {
      return secureToken;
    }

    // One-time migration path from legacy SharedPreferences storage.
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_tokenKey);
    if (legacyToken != null && legacyToken.trim().isNotEmpty) {
      await saveToken(legacyToken);
      await prefs.remove(_tokenKey);
      return legacyToken;
    }

    return null;
  }

  static Future<String?> getRefreshToken() async {
    final secureToken = await _secureStorage.read(key: _refreshTokenKey);
    if (secureToken != null && secureToken.trim().isNotEmpty) {
      return secureToken;
    }

    // One-time migration path from legacy SharedPreferences storage.
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_refreshTokenKey);
    if (legacyToken != null && legacyToken.trim().isNotEmpty) {
      await saveRefreshToken(legacyToken);
      await prefs.remove(_refreshTokenKey);
      return legacyToken;
    }

    return null;
  }

  static Future<void> clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
  }
}
