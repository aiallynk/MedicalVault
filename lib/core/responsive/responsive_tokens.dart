import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

/// Fluid design tokens layered on top of the existing flat [AppSpacing]/
/// [AppRadii] constants (`lib/core/theme/`). Those remain valid for
/// fixed-size chrome (icon badges, dividers); use these when a value should
/// grow with available width/text scale, with sensible min/max clamps so
/// nothing balloons out of control on very large screens or shrinks to
/// nothing on very small ones.
class AppResponsive {
  const AppResponsive._();

  /// Horizontal page gutter: tight on phones, more breathing room on
  /// tablets, capped so content never presses edge-to-edge on very wide
  /// screens (which looks unintentional, not "responsive").
  static double pageGutter(BuildContext context) {
    return responsiveValue(context, compact: 16.0, medium: 24.0, expanded: 32.0);
  }

  /// Vertical rhythm between major sections on a page.
  static double sectionGap(BuildContext context) {
    return responsiveValue(context, compact: 16.0, medium: 20.0, expanded: 24.0);
  }

  /// Safe maximum width for readable content (forms, article-like text,
  /// centered dialogs) on tablets/expanded screens. Phones never hit this
  /// clamp since their full width is already below it.
  static const double maxContentWidth = 720;

  /// Safe maximum width for a whole dashboard/page body on very large
  /// screens (tablets in landscape, foldables unfolded) - wider than
  /// [maxContentWidth] because grids/multi-column sections need more room
  /// than a single reading column, but still short of "edge to edge".
  static const double maxPageWidth = 1040;

  /// Minimum interactive touch-target size (WCAG 2.5.5 / Material minimum).
  static const double minTouchTarget = 48.0;

  /// Column count for grid-style layouts (dashboard tiles, doctor cards,
  /// document grids) driven by *available* width, not a fixed constant.
  static int gridColumns(double availableWidth, {double tileMinWidth = 160}) {
    final raw = (availableWidth / tileMinWidth).floor();
    return raw.clamp(1, 4);
  }
}

/// Clamps a font/icon size between [min] and [max] while still scaling with
/// the *text* scale factor (not the raw display size), so large-text
/// accessibility settings are respected without letting a single value
/// balloon past what a layout can safely absorb.
double clampedTextScale(
  BuildContext context,
  double base, {
  double min = 0.85,
  double max = 1.6,
}) {
  final scaler = MediaQuery.textScalerOf(context);
  final scaled = scaler.scale(base);
  final minScaled = base * min;
  final maxScaled = base * max;
  return scaled.clamp(minScaled, maxScaled);
}
