import 'package:flutter/material.dart';

import 'responsive_tokens.dart';

/// Standard page body shell: applies [SafeArea], a width-aware horizontal
/// gutter, and centers content with a max width on tablets/expanded screens
/// so text/forms don't stretch edge-to-edge into unreadable line lengths.
///
/// Use this instead of hand-rolling `Padding(horizontal: 16)` +
/// `SingleChildScrollView` on every screen. Pass [scrollable] = false for
/// screens that manage their own scrolling (e.g. a `CustomScrollView` or a
/// `ListView` that needs to own the full viewport, such as pull-to-refresh
/// lists) — in that case constraints/padding still apply via
/// [ResponsiveContentBounds] wrapping, but no extra scroll view is added.
class ResponsivePageBody extends StatelessWidget {
  final Widget child;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;
  final ScrollPhysics? physics;

  const ResponsivePageBody({
    super.key,
    required this.child,
    this.scrollable = true,
    this.padding,
    this.maxWidth = AppResponsive.maxPageWidth,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final gutter = AppResponsive.pageGutter(context);
    final resolvedPadding = padding ?? EdgeInsets.symmetric(horizontal: gutter);

    final content = ResponsiveContentBounds(
      maxWidth: maxWidth,
      padding: resolvedPadding,
      child: child,
    );

    if (!scrollable) {
      return SafeArea(child: content);
    }

    return SafeArea(
      child: SingleChildScrollView(
        physics: physics ?? const AlwaysScrollableScrollPhysics(),
        child: content,
      ),
    );
  }
}

/// Centers [child] and clamps it to [maxWidth], applying [padding] inside
/// the clamp. Use this directly (without [ResponsivePageBody]) when a
/// screen already owns its own `Scaffold`/scroll view but still needs its
/// content width-capped on tablets (e.g. inside a `CustomScrollView`'s
/// sliver list, or a dialog body).
class ResponsiveContentBounds extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContentBounds({
    super.key,
    required this.child,
    this.maxWidth = AppResponsive.maxPageWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final body = padding != null ? Padding(padding: padding!, child: child) : child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: body,
      ),
    );
  }
}

/// A section wrapper providing consistent vertical rhythm between stacked
/// sections on a page (dashboard blocks, settings groups, form sections).
/// Replaces ad hoc `SizedBox(height: N)` spacers scattered between sections.
class ResponsiveSection extends StatelessWidget {
  final Widget child;
  final bool addTopGap;

  const ResponsiveSection({
    super.key,
    required this.child,
    this.addTopGap = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!addTopGap) return child;
    final gap = AppResponsive.sectionGap(context);
    return Padding(
      padding: EdgeInsets.only(top: gap),
      child: child,
    );
  }
}

/// Adaptive grid delegate driven by available width rather than a fixed
/// crossAxisCount. Wraps [SliverGridDelegateWithMaxCrossAxisExtent] so
/// screens get more columns automatically on wider screens without each
/// screen re-deriving its own column-count logic.
SliverGridDelegateWithMaxCrossAxisExtent responsiveGridDelegate({
  double maxCrossAxisExtent = 220,
  double mainAxisSpacing = 12,
  double crossAxisSpacing = 12,
  double childAspectRatio = 1,
}) {
  return SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: maxCrossAxisExtent,
    mainAxisSpacing: mainAxisSpacing,
    crossAxisSpacing: crossAxisSpacing,
    childAspectRatio: childAspectRatio,
  );
}
