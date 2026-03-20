import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_text.dart';

class BottomNavItemData {
  final IconData icon;
  final String label;

  const BottomNavItemData({
    required this.icon,
    required this.label,
  });
}

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavItemData> items;
  final bool reduceMotion;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.reduceMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    final baseSurface = Color.alphaBlend(
      accentColor.withValues(alpha: 0.03),
      theme.cardColor,
    );
    final activeFill = Color.alphaBlend(
      accentColor.withValues(alpha: 0.14),
      baseSurface,
    );
    final inactiveIcon = theme.colorScheme.onSurface.withValues(alpha: 0.86);

    const barHeight = 70.0;
    const outerBorderWidth = 1.1;
    const itemHeight = 46.0;
    const barHorizontalPadding = 8.0;
    const barVerticalPadding = 8.0;
    const itemGap = 6.0;
    const selectedWeight = 2.35;
    const minInactiveSize = 28.0;
    const maxInactiveSize = 46.0;
    const minActiveWidth = 68.0;
    const maxActiveWidth = 122.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabCount = items.length;
            if (tabCount == 0) {
              return const SizedBox.shrink();
            }

            final selectedIndex = currentIndex.clamp(0, tabCount - 1);
            final inactiveCount = math.max(0, tabCount - 1);
            final contentHorizontalInset =
                barHorizontalPadding + outerBorderWidth;
            final contentVerticalInset = barVerticalPadding + outerBorderWidth;
            final rowWidth = math.max(
              0.0,
              constraints.maxWidth - (contentHorizontalInset * 2),
            );
            final availableForItems = math.max(
              0.0,
              rowWidth - (itemGap * (tabCount - 1)),
            );

            var activeWidth = availableForItems;
            var inactiveSize = 0.0;

            if (inactiveCount > 0) {
              final weightedInactive =
                  availableForItems / (inactiveCount + selectedWeight);
              inactiveSize = weightedInactive.clamp(0.0, maxInactiveSize);
              activeWidth = availableForItems - (inactiveSize * inactiveCount);

              if (activeWidth > maxActiveWidth) {
                activeWidth = maxActiveWidth;
                inactiveSize =
                    (availableForItems - activeWidth) / inactiveCount;
              }

              final minSupportedWidth =
                  minActiveWidth + (minInactiveSize * inactiveCount);
              if (availableForItems >= minSupportedWidth) {
                if (inactiveSize < minInactiveSize) {
                  inactiveSize = minInactiveSize;
                  activeWidth =
                      availableForItems - (inactiveSize * inactiveCount);
                }
                if (activeWidth < minActiveWidth) {
                  activeWidth = minActiveWidth;
                  inactiveSize =
                      (availableForItems - activeWidth) / inactiveCount;
                }
              }
            }

            activeWidth = activeWidth.clamp(0.0, availableForItems);
            inactiveSize = inactiveSize.clamp(0.0, availableForItems);

            final itemWidths = List<double>.generate(
              tabCount,
              (index) => index == selectedIndex ? activeWidth : inactiveSize,
            );

            final assignedWidth = itemWidths.fold<double>(
                  0.0,
                  (sum, width) => sum + width,
                ) +
                (itemGap * (tabCount - 1));
            final overflow = assignedWidth - rowWidth;
            if (overflow > 0 && itemWidths[selectedIndex] > overflow) {
              itemWidths[selectedIndex] -= overflow;
            }

            final separatorCenters = <double>[];
            var cursorX = contentHorizontalInset;
            for (var i = 0; i < tabCount - 1; i++) {
              cursorX += itemWidths[i];
              separatorCenters.add(cursorX + (itemGap / 2));
              cursorX += itemGap;
            }

            return SizedBox(
              height: barHeight,
              child: reduceMotion
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: baseSurface,
                        borderRadius: BorderRadius.circular(barHeight / 2),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.32),
                          width: outerBorderWidth,
                        ),
                      ),
                      child: _buildItemsRow(
                        selectedIndex: selectedIndex,
                        itemWidths: itemWidths,
                        itemHeight: itemHeight,
                        itemGap: itemGap,
                        contentHorizontalInset: contentHorizontalInset,
                        contentVerticalInset: contentVerticalInset,
                        accentColor: accentColor,
                        activeFill: activeFill,
                        inactiveIcon: inactiveIcon,
                        surfaceColor: theme.colorScheme.surface,
                      ),
                    )
                  : RepaintBoundary(
                      child: CustomPaint(
                        painter: _BottomShellPainter(
                          fillColor: baseSurface,
                          borderColor: accentColor.withValues(alpha: 0.32),
                          borderWidth: outerBorderWidth,
                          separatorXs: separatorCenters,
                        ),
                        child: _buildItemsRow(
                          selectedIndex: selectedIndex,
                          itemWidths: itemWidths,
                          itemHeight: itemHeight,
                          itemGap: itemGap,
                          contentHorizontalInset: contentHorizontalInset,
                          contentVerticalInset: contentVerticalInset,
                          accentColor: accentColor,
                          activeFill: activeFill,
                          inactiveIcon: inactiveIcon,
                          surfaceColor: theme.colorScheme.surface,
                        ),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildItemsRow({
    required int selectedIndex,
    required List<double> itemWidths,
    required double itemHeight,
    required double itemGap,
    required double contentHorizontalInset,
    required double contentVerticalInset,
    required Color accentColor,
    required Color activeFill,
    required Color inactiveIcon,
    required Color surfaceColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: contentHorizontalInset,
        vertical: contentVerticalInset,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) SizedBox(width: itemGap),
            _buildItemContainer(
              index: index,
              width: itemWidths[index],
              height: itemHeight,
              selectedIndex: selectedIndex,
              accentColor: accentColor,
              activeFill: activeFill,
              inactiveIcon: inactiveIcon,
              surfaceColor: surfaceColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemContainer({
    required int index,
    required double width,
    required double height,
    required int selectedIndex,
    required Color accentColor,
    required Color activeFill,
    required Color inactiveIcon,
    required Color surfaceColor,
  }) {
    final child = SizedBox(
      width: width,
      height: height,
      child: _NavItem(
        selected: selectedIndex == index,
        icon: items[index].icon,
        label: items[index].label,
        onTap: () => onTap(index),
        accentColor: accentColor,
        activeFill: activeFill,
        inactiveFill: surfaceColor,
        inactiveIcon: inactiveIcon,
        reduceMotion: reduceMotion,
      ),
    );

    if (reduceMotion) {
      return child;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      child: _NavItem(
        selected: selectedIndex == index,
        icon: items[index].icon,
        label: items[index].label,
        onTap: () => onTap(index),
        accentColor: accentColor,
        activeFill: activeFill,
        inactiveFill: surfaceColor,
        inactiveIcon: inactiveIcon,
        reduceMotion: false,
      ),
    );
  }
}

class _BottomShellPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final List<double> separatorXs;

  const _BottomShellPainter({
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
    required this.separatorXs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final path = _buildSegmentedShellPath(size, separatorXs);
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = fillColor;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeWidth = borderWidth
      ..color = borderColor;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _BottomShellPainter oldDelegate) {
    return fillColor != oldDelegate.fillColor ||
        borderColor != oldDelegate.borderColor ||
        borderWidth != oldDelegate.borderWidth ||
        !listEquals(separatorXs, oldDelegate.separatorXs);
  }
}

Path _buildSegmentedShellPath(Size size, List<double> separatorXs) {
  final basePath = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(size.height / 2),
      ),
    );

  if (separatorXs.isEmpty) {
    return basePath;
  }

  final notchRadius = (size.height * 0.095).clamp(4.5, 7.0).toDouble();
  final minX = (size.height / 2) + (notchRadius * 0.6);
  final maxX = size.width - minX;
  final cutouts = Path();

  for (final x in separatorXs) {
    final safeX = x.clamp(minX, maxX).toDouble();
    cutouts.addOval(
      Rect.fromCircle(
        center: Offset(safeX, 0),
        radius: notchRadius,
      ),
    );
    cutouts.addOval(
      Rect.fromCircle(
        center: Offset(safeX, size.height),
        radius: notchRadius,
      ),
    );
  }

  return Path.combine(PathOperation.difference, basePath, cutouts);
}

class _NavItem extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accentColor;
  final Color activeFill;
  final Color inactiveFill;
  final Color inactiveIcon;
  final bool reduceMotion;

  const _NavItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.accentColor,
    required this.activeFill,
    required this.inactiveFill,
    required this.inactiveIcon,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final content = _buildItemContent();
    final container = Container(
      decoration: BoxDecoration(
        color: selected ? activeFill : inactiveFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accentColor.withValues(alpha: selected ? 1 : 0.9),
          width: 1.6,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          splashColor: accentColor.withValues(alpha: 0.09),
          highlightColor: accentColor.withValues(alpha: 0.05),
          child: content,
        ),
      ),
    );

    if (reduceMotion) {
      return container;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? activeFill : inactiveFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accentColor.withValues(alpha: selected ? 1 : 0.9),
          width: 1.6,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          splashColor: accentColor.withValues(alpha: 0.09),
          highlightColor: accentColor.withValues(alpha: 0.05),
          child: _buildAnimatedContent(),
        ),
      ),
    );
  }

  Widget _buildItemContent() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: selected ? 12 : 0,
        vertical: 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 19,
            color: selected ? accentColor : inactiveIcon,
          ),
          if (selected) ...[
            const SizedBox(width: 8),
            Flexible(
              child: AppText(
                label,
                variant: AppTextVariant.caption,
                color: accentColor,
                fontWeight: FontWeight.w700,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimatedContent() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: selected ? 12 : 0,
        vertical: 10,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const iconSize = 19.0;
          const labelGap = 8.0;
          final maxLabelWidth =
              math.max(0.0, constraints.maxWidth - iconSize - labelGap);
          final targetLabelWidth = selected ? maxLabelWidth : 0.0;

          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: selected ? accentColor : inactiveIcon,
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                width: targetLabelWidth,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: selected ? 1 : 0,
                      child: Padding(
                        padding: const EdgeInsets.only(left: labelGap),
                        child: AppText(
                          label,
                          variant: AppTextVariant.caption,
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
