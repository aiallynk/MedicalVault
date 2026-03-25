import 'package:flutter/material.dart';

import '../core/theme/theme.dart';
import 'app_text.dart';

/// Reusable section wrapper for settings pages.
/// Keeps consistent spacing, rounding, and calm neutral surfaces.
class SectionContainer extends StatelessWidget {
  const SectionContainer({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : const Color(0xFFDCE3EC),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
            blurRadius: isDark ? 18 : 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        title,
                        variant: AppTextVariant.body,
                        fontWeight: FontWeight.w700,
                      ),
                      if ((subtitle ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        AppText(
                          subtitle!,
                          variant: AppTextVariant.caption,
                          color: theme.textTheme.bodyMedium?.color,
                          maxLines: 3,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Reusable settings list tile with icon, subtitle and optional action.
class SettingTile extends StatelessWidget {
  const SettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      title,
                      variant: AppTextVariant.body,
                      fontWeight: FontWeight.w700,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    AppText(
                      subtitle,
                      variant: AppTextVariant.caption,
                      color: theme.textTheme.bodyMedium?.color,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
            ],
          ),
          if (showDivider)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Divider(
                height: 1,
                color: theme.dividerColor,
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: content,
      ),
    );
  }
}

class AccentChoice {
  const AccentChoice({
    required this.palette,
    required this.label,
    required this.color,
  });

  final AppThemePalette palette;
  final String label;
  final Color color;
}

/// Grid for selecting one of the curated accent colors.
/// Designed for calm, compact selection without full-card color fills.
class ColorPickerGrid extends StatelessWidget {
  const ColorPickerGrid({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<AccentChoice> options;
  final AppThemePalette? selected;
  final ValueChanged<AppThemePalette> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.74,
      ),
      itemBuilder: (context, index) {
        final item = options[index];
        final isSelected = selected != null && item.palette == selected;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelected(item.palette),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 90;
                final swatchSize = compact ? 40.0 : 44.0;
                final swatchInset = compact ? 3.0 : 4.0;
                final gap = compact ? 4.0 : 6.0;

                return Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: swatchSize,
                      height: swatchSize,
                      padding: EdgeInsets.all(swatchInset),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.dividerColor,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: item.color.withValues(alpha: 0.35),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SizedBox(height: gap),
                    Expanded(
                      child: Center(
                        child: AppText(
                          item.label,
                          variant: AppTextVariant.caption,
                          textAlign: TextAlign.center,
                          color: theme.textTheme.bodyMedium?.color,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
