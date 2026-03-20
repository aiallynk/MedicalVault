import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_radii.dart';

enum AppThemePalette { teal, purple, custom }

AppThemePalette appThemePaletteFromStorage(String? value) {
  switch (value) {
    case 'custom':
      return AppThemePalette.custom;
    case 'purple':
      return AppThemePalette.purple;
    case 'teal':
    default:
      return AppThemePalette.teal;
  }
}

String appThemePaletteToStorage(AppThemePalette palette) {
  switch (palette) {
    case AppThemePalette.custom:
      return 'custom';
    case AppThemePalette.purple:
      return 'purple';
    case AppThemePalette.teal:
      return 'teal';
  }
}

String appThemePaletteLabel(AppThemePalette palette) {
  switch (palette) {
    case AppThemePalette.custom:
      return 'Custom';
    case AppThemePalette.purple:
      return 'Indigo Aura';
    case AppThemePalette.teal:
      return 'Emerald Calm';
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
    final lead = Color.lerp(
      colors.primary,
      Colors.white,
      brightness == Brightness.dark ? 0.04 : 0.14,
    )!;
    if (palette == AppThemePalette.custom && customSecondaryColor != null) {
      return [lead, colors.primary, colors.secondary];
    }
    return [lead, colors.secondary];
  }

  static AppColors _resolveColors(
    AppThemePalette palette,
    Brightness brightness, {
    Color? customPrimaryColor,
    Color? customSecondaryColor,
  }) {
    switch (palette) {
      case AppThemePalette.custom:
        final base = customPrimaryColor ?? const Color(0xFF0F9D94);
        return _customPaletteFromColor(
          base,
          brightness,
          customSecondaryColor: customSecondaryColor,
        );
      case AppThemePalette.purple:
        return brightness == Brightness.dark
            ? AppColors.purpleDark
            : AppColors.purpleLight;
      case AppThemePalette.teal:
        return brightness == Brightness.dark
            ? AppColors.tealDark
            : AppColors.tealLight;
    }
  }

  static AppColors _customPaletteFromColor(
    Color base,
    Brightness brightness, {
    Color? customSecondaryColor,
  }) {
    final hsl = HSLColor.fromColor(base);
    final derivedSecondary = hsl
        .withHue((hsl.hue + 28) % 360)
        .withSaturation((hsl.saturation + 0.08).clamp(0.25, 0.92))
        .withLightness(
          brightness == Brightness.dark ? 0.64 : 0.5,
        )
        .toColor();
    final secondary = _resolveCustomSecondary(
      customSecondaryColor,
      brightness,
      fallback: derivedSecondary,
    );

    if (brightness == Brightness.dark) {
      final bg = Color.alphaBlend(
        base.withValues(alpha: 0.08),
        const Color(0xFF000000),
      );
      final surface = Color.alphaBlend(
        base.withValues(alpha: 0.11),
        const Color(0xFF0B0B0B),
      );
      return AppColors(
        primary: hsl.withLightness(0.62).toColor(),
        secondary: secondary,
        background: bg,
        surface: surface,
        textPrimary: const Color(0xFFF1F5FF),
        textSecondary: const Color(0xFFBCC8DB),
      );
    }

    final bg = Color.alphaBlend(base.withValues(alpha: 0.08), Colors.white);
    final surface =
        Color.alphaBlend(base.withValues(alpha: 0.04), Colors.white);
    return AppColors(
      primary: hsl.withLightness(0.42).toColor(),
      secondary: secondary,
      background: bg,
      surface: surface,
      textPrimary: const Color(0xFF102A43),
      textSecondary: const Color(0xFF5A6E85),
    );
  }

  static Color _resolveCustomSecondary(
    Color? candidate,
    Brightness brightness, {
    required Color fallback,
  }) {
    if (candidate == null) return fallback;
    final hsl = HSLColor.fromColor(candidate);
    return hsl
        .withSaturation((hsl.saturation + 0.04).clamp(0.25, 0.94))
        .withLightness(brightness == Brightness.dark ? 0.66 : 0.52)
        .toColor();
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
    final surfaceElevated = Color.alphaBlend(
      colors.primary.withValues(alpha: isDark ? 0.12 : 0.035),
      colors.surface,
    );
    final outlineSoft = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : colors.primary.withValues(alpha: 0.14);

    final baseText = isDark
        ? ThemeData.dark(useMaterial3: true).textTheme
        : ThemeData.light(useMaterial3: true).textTheme;
    final textTheme = GoogleFonts.poppinsTextTheme(baseText).copyWith(
      headlineSmall: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
      ),
      labelLarge: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
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
      dividerColor: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.08),
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
        color: surfaceElevated,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isDark ? colors.surface.withValues(alpha: 0.88) : colors.surface,
        hintStyle: textTheme.bodyMedium,
        labelStyle: textTheme.bodyMedium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(
            color: outlineSoft,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(
            color: outlineSoft,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(
            color: colors.primary,
            width: 1.3,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? surfaceElevated : colors.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? colors.textPrimary : Colors.white,
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
          side: BorderSide(
            color: colors.primary.withValues(alpha: 0.32),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          foregroundColor: colors.primary,
          textStyle: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          textStyle: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        selectedColor: colors.primary.withValues(alpha: 0.16),
        backgroundColor: brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : colors.primary.withValues(alpha: 0.08),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w500,
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
        backgroundColor: Color.alphaBlend(
          colors.primary.withValues(alpha: isDark ? 0.08 : 0.03),
          colors.surface,
        ),
        indicatorColor: colors.primary.withValues(alpha: 0.16),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceElevated,
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
