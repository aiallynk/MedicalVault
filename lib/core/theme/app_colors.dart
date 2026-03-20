import 'package:flutter/material.dart';

@immutable
class AppColors {
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;

  const AppColors({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  static const AppColors tealLight = AppColors(
    primary: Color(0xFF0D8D85),
    secondary: Color(0xFF12B5A0),
    background: Color(0xFFF0F8F7),
    surface: Color(0xFFFDFEFE),
    textPrimary: Color(0xFF102933),
    textSecondary: Color(0xFF59707D),
  );

  static const AppColors tealDark = AppColors(
    primary: Color(0xFF35D7C1),
    secondary: Color(0xFF4CE8CC),
    background: Color(0xFF061715),
    surface: Color(0xFF0D2320),
    textPrimary: Color(0xFFE8FAF7),
    textSecondary: Color(0xFFA8C9C2),
  );

  static const AppColors purpleLight = AppColors(
    primary: Color(0xFF5A6BFF),
    secondary: Color(0xFF8A5CF4),
    background: Color(0xFFF4F5FF),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1B2448),
    textSecondary: Color(0xFF5E6B8F),
  );

  static const AppColors purpleDark = AppColors(
    primary: Color(0xFF8F9EFF),
    secondary: Color(0xFFB690FF),
    background: Color(0xFF0A1022),
    surface: Color(0xFF121B34),
    textPrimary: Color(0xFFEAF0FF),
    textSecondary: Color(0xFFB9C2E6),
  );
}
