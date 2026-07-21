import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/core/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider default for a brand-new user', () {
    test('with no saved preferences at all, defaults to the Aqua Shield gradient', () async {
      SharedPreferences.setMockInitialValues({});

      final config = await ThemeProvider.loadThemeConfig();

      expect(config.palette, AppThemePalette.custom);
      expect(config.customPrimaryColorValue,
          AppDefaultTheme.gradientStart.toARGB32());
      expect(config.customSecondaryColorValue,
          AppDefaultTheme.gradientEnd.toARGB32());
    });

    test('never picks up a plain solid teal default', () async {
      SharedPreferences.setMockInitialValues({});

      final config = await ThemeProvider.loadThemeConfig();

      // The old behavior (before this fix) fell back to a solid teal accent
      // with no secondary/gradient color at all.
      expect(config.customSecondaryColorValue, isNotNull);
      expect(config.palette, isNot(AppThemePalette.teal));
    });

    test('a previously saved palette is preserved and not overridden', () async {
      SharedPreferences.setMockInitialValues({
        'app_theme_mode': 'dark',
        'app_theme_palette': 'emerald',
      });

      final config = await ThemeProvider.loadThemeConfig();

      expect(config.themeMode, ThemeMode.dark);
      expect(config.palette, AppThemePalette.emerald);
      expect(config.customPrimaryColorValue, isNull);
      expect(config.customSecondaryColorValue, isNull);
    });

    test('a previously saved custom gradient is preserved and not overridden', () async {
      const savedPrimary = 0xFF112233;
      const savedSecondary = 0xFF445566;
      SharedPreferences.setMockInitialValues({
        'app_theme_palette': 'custom',
        'app_theme_custom_primary': savedPrimary,
        'app_theme_custom_secondary': savedSecondary,
      });

      final config = await ThemeProvider.loadThemeConfig();

      expect(config.palette, AppThemePalette.custom);
      expect(config.customPrimaryColorValue, savedPrimary);
      expect(config.customSecondaryColorValue, savedSecondary);
    });
  });

  group('ThemeProvider.clearCustomPrimaryColor', () {
    test('resets a custom palette back to the Aqua Shield default, not solid teal', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider(
        themeMode: ThemeMode.light,
        palette: AppThemePalette.custom,
        customPrimaryColorValue: 0xFF112233,
        customSecondaryColorValue: 0xFF445566,
      );

      await provider.clearCustomPrimaryColor();

      expect(provider.palette, AppThemePalette.custom);
      expect(provider.customPrimaryColorValue,
          AppDefaultTheme.gradientStart.toARGB32());
      expect(provider.customSecondaryColorValue,
          AppDefaultTheme.gradientEnd.toARGB32());
    });
  });
}
