import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

class ThemeProviderConfig {
  final ThemeMode themeMode;
  final AppThemePalette palette;
  final int? customPrimaryColorValue;
  final int? customSecondaryColorValue;

  const ThemeProviderConfig({
    required this.themeMode,
    required this.palette,
    this.customPrimaryColorValue,
    this.customSecondaryColorValue,
  });
}

class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'app_theme_mode';
  static const String _themePaletteKey = 'app_theme_palette';
  static const String _customThemeColorKey = 'app_theme_custom_primary';
  static const String _customThemeSecondaryColorKey =
      'app_theme_custom_secondary';

  ThemeMode _themeMode;
  AppThemePalette _palette;
  int? _customPrimaryColorValue;
  int? _customSecondaryColorValue;

  ThemeProvider({
    required ThemeMode themeMode,
    required AppThemePalette palette,
    int? customPrimaryColorValue,
    int? customSecondaryColorValue,
  })  : _themeMode = themeMode,
        _palette = palette,
        _customPrimaryColorValue = customPrimaryColorValue,
        _customSecondaryColorValue = customSecondaryColorValue;

  ThemeMode get themeMode => _themeMode;
  AppThemePalette get palette => _palette;
  int? get customPrimaryColorValue => _customPrimaryColorValue;
  int? get customSecondaryColorValue => _customSecondaryColorValue;
  Color? get customPrimaryColor => _customPrimaryColorValue == null
      ? null
      : Color(_customPrimaryColorValue!);
  Color? get customSecondaryColor => _customSecondaryColorValue == null
      ? null
      : Color(_customSecondaryColorValue!);
  bool get hasCustomGradient => customSecondaryColor != null;

  ThemeData get lightTheme => AppThemes.lightTheme(
        _palette,
        customPrimaryColor: customPrimaryColor,
        customSecondaryColor: customSecondaryColor,
      );
  ThemeData get darkTheme => AppThemes.darkTheme(
        _palette,
        customPrimaryColor: customPrimaryColor,
        customSecondaryColor: customSecondaryColor,
      );

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  static Future<ThemeProviderConfig> loadThemeConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_themeModeKey);
    final savedPalette = prefs.getString(_themePaletteKey);

    return ThemeProviderConfig(
      themeMode: _themeModeFromStorage(savedMode),
      palette: appThemePaletteFromStorage(savedPalette),
      customPrimaryColorValue: prefs.getInt(_customThemeColorKey),
      customSecondaryColorValue: prefs.getInt(_customThemeSecondaryColorKey),
    );
  }

  static Future<bool> hasSavedThemePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_themeModeKey) ||
        prefs.containsKey(_themePaletteKey) ||
        prefs.containsKey(_customThemeColorKey) ||
        prefs.containsKey(_customThemeSecondaryColorKey);
  }

  static Future<ThemeMode> loadThemeMode() async {
    final config = await loadThemeConfig();
    return config.themeMode;
  }

  static Future<AppThemePalette> loadThemePalette() async {
    final config = await loadThemeConfig();
    return config.palette;
  }

  Future<void> toggleTheme() async {
    final next =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _persist();
    notifyListeners();
  }

  Future<void> setPalette(AppThemePalette palette) async {
    if (_palette == palette) return;
    _palette = palette;
    await _persist();
    notifyListeners();
  }

  Future<void> setCustomPrimaryColor(Color color) async {
    _customPrimaryColorValue = _toColorValue(color);
    _customSecondaryColorValue = null;
    _palette = AppThemePalette.custom;
    await _persist();
    notifyListeners();
  }

  Future<void> setCustomGradientColors({
    required Color primary,
    required Color secondary,
  }) async {
    _customPrimaryColorValue = _toColorValue(primary);
    _customSecondaryColorValue = _toColorValue(secondary);
    _palette = AppThemePalette.custom;
    await _persist();
    notifyListeners();
  }

  Future<void> clearCustomPrimaryColor() async {
    _customPrimaryColorValue = null;
    _customSecondaryColorValue = null;
    if (_palette == AppThemePalette.custom) {
      _palette = AppThemePalette.teal;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> applyRemoteUiConfig(
    Map<String, dynamic> config, {
    bool persist = true,
  }) async {
    bool changed = false;

    final remoteButtonColor = parseHexColor(config['buttonColor']);
    final remoteIconColor = parseHexColor(config['iconColor']);
    final remoteThemeMode = parseThemeMode(config['themeMode']);

    if (remoteButtonColor != null) {
      _customPrimaryColorValue = _toColorValue(remoteButtonColor);
      _customSecondaryColorValue =
          remoteIconColor != null ? _toColorValue(remoteIconColor) : null;
      _palette = AppThemePalette.custom;
      changed = true;
    }

    if (remoteThemeMode != null && _themeMode != remoteThemeMode) {
      _themeMode = remoteThemeMode;
      changed = true;
    }

    if (!changed) return;
    if (persist) await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _themeModeToStorage(_themeMode));
    await prefs.setString(_themePaletteKey, appThemePaletteToStorage(_palette));
    if (_customPrimaryColorValue != null) {
      await prefs.setInt(_customThemeColorKey, _customPrimaryColorValue!);
    } else {
      await prefs.remove(_customThemeColorKey);
    }
    if (_customSecondaryColorValue != null) {
      await prefs.setInt(
        _customThemeSecondaryColorKey,
        _customSecondaryColorValue!,
      );
    } else {
      await prefs.remove(_customThemeSecondaryColorKey);
    }
  }

  static int _toColorValue(Color color) {
    final a = (color.a * 255).round() & 0xFF;
    final r = (color.r * 255).round() & 0xFF;
    final g = (color.g * 255).round() & 0xFF;
    final b = (color.b * 255).round() & 0xFF;
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  static Color? parseHexColor(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    var hex = raw.replaceAll('#', '').replaceAll('0x', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final intValue = int.tryParse(hex, radix: 16);
    if (intValue == null) return null;
    return Color(intValue);
  }

  static ThemeMode? parseThemeMode(dynamic value) {
    final mode = value?.toString().trim().toUpperCase();
    switch (mode) {
      case 'LIGHT':
        return ThemeMode.light;
      case 'DARK':
        return ThemeMode.dark;
      case 'SYSTEM':
        return ThemeMode.system;
      default:
        return null;
    }
  }

  static ThemeMode _themeModeFromStorage(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  static String _themeModeToStorage(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
    }
  }
}
