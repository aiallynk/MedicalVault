import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StatusBarHelper {
  const StatusBarHelper._();

  static void configureSystemUiMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  static void setStatusBarStyle(
    BuildContext context, {
    bool transparentStatusBar = true,
    bool transparentNavigationBar = false,
  }) {
    final theme = Theme.of(context);
    SystemChrome.setSystemUIOverlayStyle(
      overlayStyleForTheme(
        theme,
        transparentStatusBar: transparentStatusBar,
        transparentNavigationBar: transparentNavigationBar,
      ),
    );
  }

  static void setStatusBarStyleForMode(ThemeMode mode) {
    final brightness =
        mode == ThemeMode.dark ? Brightness.dark : Brightness.light;
    SystemChrome.setSystemUIOverlayStyle(
      overlayStyleForBrightness(
        brightness,
        transparentStatusBar: true,
        transparentNavigationBar: false,
      ),
    );
  }

  static SystemUiOverlayStyle overlayStyleForTheme(
    ThemeData theme, {
    Color? statusBarColor,
    Color? navigationBarColor,
    bool transparentStatusBar = true,
    bool transparentNavigationBar = false,
  }) {
    final fallbackSurface = theme.scaffoldBackgroundColor;
    final resolvedStatusBarColor = transparentStatusBar
        ? Colors.transparent
        : (statusBarColor ?? fallbackSurface);
    final resolvedNavigationBarColor = transparentNavigationBar
        ? Colors.transparent
        : (navigationBarColor ?? fallbackSurface);

    final statusIconBrightness = _iconBrightnessForBackground(
      statusBarColor ?? fallbackSurface,
    );
    final navIconBrightness = _iconBrightnessForBackground(
      navigationBarColor ?? fallbackSurface,
    );
    final statusBackgroundBrightness =
        _backgroundBrightness(statusBarColor ?? fallbackSurface);

    return SystemUiOverlayStyle(
      statusBarColor: resolvedStatusBarColor,
      statusBarIconBrightness: statusIconBrightness,
      statusBarBrightness: statusBackgroundBrightness,
      systemNavigationBarColor: resolvedNavigationBarColor,
      systemNavigationBarIconBrightness: navIconBrightness,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }

  static SystemUiOverlayStyle overlayStyleForBrightness(
    Brightness brightness, {
    Color? statusBarColor,
    Color? navigationBarColor,
    bool transparentStatusBar = true,
    bool transparentNavigationBar = false,
  }) {
    final baseColor =
        brightness == Brightness.dark ? const Color(0xFF000000) : Colors.white;
    final resolvedStatus = statusBarColor ?? baseColor;
    final resolvedNav = navigationBarColor ?? baseColor;

    return overlayStyleForTheme(
      ThemeData(brightness: brightness),
      statusBarColor: resolvedStatus,
      navigationBarColor: resolvedNav,
      transparentStatusBar: transparentStatusBar,
      transparentNavigationBar: transparentNavigationBar,
    );
  }

  static Brightness _iconBrightnessForBackground(Color color) {
    final estimated = ThemeData.estimateBrightnessForColor(color);
    return estimated == Brightness.dark ? Brightness.light : Brightness.dark;
  }

  static Brightness _backgroundBrightness(Color color) {
    return ThemeData.estimateBrightnessForColor(color);
  }
}
