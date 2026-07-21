import 'package:flutter/widgets.dart';

/// Layout size categories driven by *available width*, never device model
/// or platform. A foldable at 700dp and a small tablet at 700dp get the
/// same category — that's the point.
enum WindowSizeClass { compact, medium, expanded }

/// Centralized breakpoints for the whole app. Values follow Material 3's
/// window-size-class guidance (compact <600, medium 600-839, expanded 840+)
/// rather than arbitrary numbers invented per screen.
class AppBreakpoints {
  const AppBreakpoints._();

  static const double compactMax = 600;
  static const double mediumMax = 840;

  static WindowSizeClass classify(double width) {
    if (width < compactMax) return WindowSizeClass.compact;
    if (width < mediumMax) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }
}

/// Resolves the current [WindowSizeClass] and exposes small helpers so call
/// sites read as intent ("isCompact") instead of repeating width math.
class AppWindowSize {
  final double width;
  final double height;
  final Orientation orientation;
  final WindowSizeClass sizeClass;

  const AppWindowSize({
    required this.width,
    required this.height,
    required this.orientation,
  }) : sizeClass = width < AppBreakpoints.compactMax
            ? WindowSizeClass.compact
            : width < AppBreakpoints.mediumMax
                ? WindowSizeClass.medium
                : WindowSizeClass.expanded;

  bool get isCompact => sizeClass == WindowSizeClass.compact;
  bool get isMedium => sizeClass == WindowSizeClass.medium;
  bool get isExpanded => sizeClass == WindowSizeClass.expanded;

  /// Medium or wider — the point at which two-column layouts become viable.
  bool get isAtLeastMedium => sizeClass != WindowSizeClass.compact;

  bool get isLandscape => orientation == Orientation.landscape;
  bool get isPortrait => orientation == Orientation.portrait;

  /// Reads window size from [MediaQuery]. Prefer this at the top of a page;
  /// pass the resolved [AppWindowSize] down instead of re-reading MediaQuery
  /// in every descendant.
  factory AppWindowSize.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    return AppWindowSize(
      width: mq.size.width,
      height: mq.size.height,
      orientation: mq.orientation,
    );
  }

  /// Variant for use inside a [LayoutBuilder], where the *available* width
  /// (e.g. inside a side-by-side layout) may be narrower than the full
  /// screen — this is almost always what you want for nested layout
  /// decisions, vs. the full-screen [AppWindowSize.of].
  factory AppWindowSize.fromConstraints(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final orientation = MediaQuery.orientationOf(context);
    return AppWindowSize(
      width: constraints.maxWidth,
      height: constraints.maxHeight,
      orientation: orientation,
    );
  }
}

/// Picks a value based on the current window size class. Use this instead of
/// scattering `if (width < 600)` checks throughout screens.
T responsiveValue<T>(
  BuildContext context, {
  required T compact,
  T? medium,
  T? expanded,
}) {
  final sizeClass = AppWindowSize.of(context).sizeClass;
  return switch (sizeClass) {
    WindowSizeClass.compact => compact,
    WindowSizeClass.medium => medium ?? compact,
    WindowSizeClass.expanded => expanded ?? medium ?? compact,
  };
}
