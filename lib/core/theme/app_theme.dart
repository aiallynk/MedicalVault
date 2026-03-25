import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_radii.dart';

enum AppThemePalette {
  teal,
  softBlue,
  indigo,
  emerald,
  warmGray,
  mutedPurple,
  softOrange,
  softRose,
  custom,
}

AppThemePalette appThemePaletteFromStorage(String? value) {
  switch (value) {
    case 'soft_blue':
      return AppThemePalette.softBlue;
    case 'indigo':
    case 'purple':
      return AppThemePalette.indigo;
    case 'emerald':
      return AppThemePalette.emerald;
    case 'warm_gray':
      return AppThemePalette.warmGray;
    case 'muted_purple':
      return AppThemePalette.mutedPurple;
    case 'soft_orange':
      return AppThemePalette.softOrange;
    case 'soft_rose':
      return AppThemePalette.softRose;
    case 'custom':
      return AppThemePalette.custom;
    case 'teal':
    default:
      return AppThemePalette.teal;
  }
}

String appThemePaletteToStorage(AppThemePalette palette) {
  switch (palette) {
    case AppThemePalette.softBlue:
      return 'soft_blue';
    case AppThemePalette.indigo:
      return 'indigo';
    case AppThemePalette.emerald:
      return 'emerald';
    case AppThemePalette.warmGray:
      return 'warm_gray';
    case AppThemePalette.mutedPurple:
      return 'muted_purple';
    case AppThemePalette.softOrange:
      return 'soft_orange';
    case AppThemePalette.softRose:
      return 'soft_rose';
    case AppThemePalette.custom:
      return 'custom';
    case AppThemePalette.teal:
      return 'teal';
  }
}

String appThemePaletteLabel(AppThemePalette palette) {
  switch (palette) {
    case AppThemePalette.teal:
      return 'Teal';
    case AppThemePalette.softBlue:
      return 'Soft Blue';
    case AppThemePalette.indigo:
      return 'Indigo';
    case AppThemePalette.emerald:
      return 'Emerald';
    case AppThemePalette.warmGray:
      return 'Warm Gray';
    case AppThemePalette.mutedPurple:
      return 'Muted Purple';
    case AppThemePalette.softOrange:
      return 'Soft Orange';
    case AppThemePalette.softRose:
      return 'Soft Rose';
    case AppThemePalette.custom:
      return 'Custom';
  }
}

class AppThemes {
  const AppThemes._();

  static ThemeData lightTheme(
    AppThemePalette palette, {
    Color? customPrimaryColor,
    Color? customSecondaryColor,
  }) {
    return _buildTheme(
      brightness: Brightness.light,
      colors: _resolveColors(
        palette,
        Brightness.light,
        customPrimaryColor: customPrimaryColor,
        customSecondaryColor: customSecondaryColor,
      ),
    );
  }

  static ThemeData darkTheme(
    AppThemePalette palette, {
    Color? customPrimaryColor,
    Color? customSecondaryColor,
  }) {
    return _buildTheme(
      brightness: Brightness.dark,
      colors: _resolveColors(
        palette,
        Brightness.dark,
        customPrimaryColor: customPrimaryColor,
        customSecondaryColor: customSecondaryColor,
      ),
    );
  }

  static AppColors colorsFor(
    AppThemePalette palette,
    Brightness brightness, {
    Color? customPrimaryColor,
    Color? customSecondaryColor,
  }) {
    return _resolveColors(
      palette,
      brightness,
      customPrimaryColor: customPrimaryColor,
      customSecondaryColor: customSecondaryColor,
    );
  }

  static List<Color> primaryGradient(
    AppThemePalette palette,
    Brightness brightness, {
    Color? customPrimaryColor,
    Color? customSecondaryColor,
  }) {
    final colors = _resolveColors(
      palette,
      brightness,
      customPrimaryColor: customPrimaryColor,
      customSecondaryColor: customSecondaryColor,
    );

    final lead = Color.alphaBlend(
      colors.primary
          .withValues(alpha: brightness == Brightness.dark ? 0.32 : 0.2),
      colors.surface,
    );
    final tail = Color.alphaBlend(
      colors.secondary
          .withValues(alpha: brightness == Brightness.dark ? 0.24 : 0.14),
      colors.surface,
    );

    return [lead, tail];
  }

  static AppColors _resolveColors(
    AppThemePalette palette,
    Brightness brightness, {
    Color? customPrimaryColor,
    Color? customSecondaryColor,
  }) {
    if (palette == AppThemePalette.custom) {
      final fallback = brightness == Brightness.dark
          ? const Color(0xFF5CCAC2)
          : const Color(0xFF0E8D86);
      return _medicalPaletteFromAccent(
        customPrimaryColor ?? fallback,
        brightness,
        customSecondaryColor: customSecondaryColor,
      );
    }

    final accent = _accentForPalette(palette, brightness);
    return _medicalPaletteFromAccent(accent, brightness);
  }

  static Color _accentForPalette(
      AppThemePalette palette, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (palette) {
      case AppThemePalette.teal:
        return isDark ? const Color(0xFF5DE0D5) : const Color(0xFF0DA29A);
      case AppThemePalette.softBlue:
        return isDark ? const Color(0xFF8FC2FF) : const Color(0xFF2F7CDE);
      case AppThemePalette.indigo:
        return isDark ? const Color(0xFFA9B6FF) : const Color(0xFF4B5FE6);
      case AppThemePalette.emerald:
        return isDark ? const Color(0xFF76E1B8) : const Color(0xFF1F9D73);
      case AppThemePalette.warmGray:
        return isDark ? const Color(0xFFC0CAD7) : const Color(0xFF64758A);
      case AppThemePalette.mutedPurple:
        return isDark ? const Color(0xFFC4B8F2) : const Color(0xFF705CCF);
      case AppThemePalette.softOrange:
        return isDark ? const Color(0xFFFFC588) : const Color(0xFFD98333);
      case AppThemePalette.softRose:
        return isDark ? const Color(0xFFE8A7BC) : const Color(0xFFBB5F79);
      case AppThemePalette.custom:
        return isDark ? const Color(0xFF5CCAC2) : const Color(0xFF0E8D86);
    }
  }

  static AppColors _medicalPaletteFromAccent(
    Color accent,
    Brightness brightness, {
    Color? customSecondaryColor,
  }) {
    final isDark = brightness == Brightness.dark;
    final hsl = HSLColor.fromColor(accent);
    final normalizedPrimary = hsl
        .withSaturation((hsl.saturation * 1.02).clamp(0.18, 0.9))
        .withLightness(isDark ? 0.68 : 0.46)
        .toColor();

    final secondary = customSecondaryColor ??
        hsl
            .withHue((hsl.hue + 18) % 360)
            .withSaturation((hsl.saturation * 0.86).clamp(0.18, 0.7))
            .withLightness(isDark ? 0.74 : 0.54)
            .toColor();

    if (isDark) {
      return AppColors(
        primary: normalizedPrimary,
        secondary: secondary,
        background: const Color(0xFF0B0F1A),
        surface: const Color(0xFF141B2A),
        textPrimary: const Color(0xFFEAF0FA),
        textSecondary: const Color(0xFFA6B2C4),
      );
    }

    return AppColors(
      primary: normalizedPrimary,
      secondary: secondary,
      background: const Color(0xFFF4F7FB),
      surface: const Color(0xFFFFFFFF),
      textPrimary: const Color(0xFF0E1726),
      textSecondary: const Color(0xFF5A6678),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppColors colors,
  }) {
    final isDark = brightness == Brightness.dark;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: brightness,
    );

    final scheme = baseScheme.copyWith(
      primary: colors.primary,
      secondary: colors.secondary,
      surface: colors.surface,
      onSurface: colors.textPrimary,
    );

    final outlineSoft =
        isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFDEE5EE);

    final baseText = isDark
        ? ThemeData.dark(useMaterial3: true).textTheme
        : ThemeData.light(useMaterial3: true).textTheme;

    final textTheme = GoogleFonts.manropeTextTheme(baseText).copyWith(
      headlineSmall: GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      cardColor: colors.surface,
      canvasColor: colors.background,
      textTheme: textTheme,
      iconTheme: IconThemeData(
        color: colors.textPrimary.withValues(alpha: 0.92),
      ),
      dividerColor: outlineSoft,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle:
            (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: colors.background,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: colors.surface,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1A2235) : const Color(0xFFF8FAFD),
        hintStyle: textTheme.bodyMedium,
        labelStyle: textTheme.bodyMedium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: outlineSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: outlineSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(
            color: colors.primary,
            width: 1.35,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF1A2233) : colors.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          side: BorderSide(color: colors.primary.withValues(alpha: 0.36)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          foregroundColor: colors.primary,
          textStyle: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          textStyle: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        selectedColor: colors.primary.withValues(alpha: 0.18),
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : colors.primary.withValues(alpha: 0.09),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.textSecondary,
        showUnselectedLabels: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withValues(alpha: 0.16),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textPrimary.withValues(alpha: 0.9),
      ),
    );
  }
}
