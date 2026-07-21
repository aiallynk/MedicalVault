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
    final hasSavedPalette = prefs.containsKey(_themePaletteKey);
    final savedPrimaryColorValue = prefs.getInt(_customThemeColorKey);
    final savedSecondaryColorValue = prefs.getInt(_customThemeSecondaryColorKey);

    // A brand-new user has no saved palette yet: default to the Aqua Shield
    // gradient (the same gradient selectable in Theme Studio), never to a
    // remote/backend-configured color.
    if (!hasSavedPalette) {
      return ThemeProviderConfig(
        themeMode: _themeModeFromStorage(savedMode),
        palette: AppThemePalette.custom,
        customPrimaryColorValue: _toColorValue(AppDefaultTheme.gradientStart),
        customSecondaryColorValue: _toColorValue(AppDefaultTheme.gradientEnd),
      );
    }

    return ThemeProviderConfig(
      themeMode: _themeModeFromStorage(savedMode),
      palette: appThemePaletteFromStorage(savedPalette),
      customPrimaryColorValue: savedPrimaryColorValue,
      customSecondaryColorValue: savedSecondaryColorValue,
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
    if (_palette == AppThemePalette.custom) {
      // Reset to the same Aqua Shield default a brand-new user starts on.
      _customPrimaryColorValue = _toColorValue(AppDefaultTheme.gradientStart);
      _customSecondaryColorValue = _toColorValue(AppDefaultTheme.gradientEnd);
    } else {
      _customPrimaryColorValue = null;
      _customSecondaryColorValue = null;
    }
    await _persist();
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
