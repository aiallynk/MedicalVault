import 'package:flutter/material.dart';

import '../core/theme/theme.dart';
import 'app_text.dart';

class SettingsTokens {
  const SettingsTokens._();

  static const double pageHorizontal = 16;
  static const double pageTop = 18;
  static const double pageBottom = 28;
  static const double sectionGap = 18;
  static const double blockGap = 12;
  static const double cardRadius = 22;
  static const double groupRadius = 20;
  static const double tileRadius = 18;
  static const double iconRadius = 14;
  static const double iconSize = 20;
  static const double iconBadgeSize = 42;
  static const double tileMinHeight = 72;
  static const double headerIconSize = 48;
  static const Duration interactionDuration = Duration(milliseconds: 220);
  static const Duration routeDuration = Duration(milliseconds: 280);
  static const Curve interactionCurve = Curves.easeOutCubic;
}

class SettingsPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  const SettingsPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = SettingsVisuals.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsIconBadge(
          icon: icon,
          accentColor: visuals.accent,
          size: SettingsTokens.headerIconSize,
          iconSize: 24,
          radius: 16,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                title,
                variant: AppTextVariant.title,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 4),
              AppText(
                subtitle,
                variant: AppTextVariant.body,
                color: visuals.secondaryText,
                maxLines: 3,
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class SettingsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const SettingsSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(
          title: title,
          subtitle: subtitle,
          trailing: trailing,
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class SettingsSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const SettingsSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = SettingsVisuals.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                title,
                variant: AppTextVariant.subtitle,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 2),
              AppText(
                subtitle,
                variant: AppTextVariant.caption,
                color: visuals.secondaryText,
                maxLines: 3,
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class SettingsSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const SettingsSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = SettingsVisuals.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(SettingsTokens.cardRadius),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: visuals.surface,
              borderRadius: BorderRadius.circular(SettingsTokens.cardRadius),
              border: Border.all(color: visuals.outline),
              boxShadow: visuals.cardShadow,
            ),
            child: Row(
              children: [
                _SettingsIconBadge(
                  icon: icon,
                  accentColor: visuals.accent,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        title,
                        variant: AppTextVariant.body,
                        fontWeight: FontWeight.w700,
                      ),
                      const SizedBox(height: 4),
                      AppText(
                        subtitle,
                        variant: AppTextVariant.caption,
                        color: visuals.secondaryText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _SettingsChevron(color: visuals.chevron),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsGroupCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SettingsGroupCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final visuals = SettingsVisuals.of(context);

    return Container(
      decoration: BoxDecoration(
        color: visuals.surface,
        borderRadius: BorderRadius.circular(SettingsTokens.groupRadius),
        border: Border.all(color: visuals.outline),
        boxShadow: visuals.cardShadow,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class SettingsItemTile extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final bool dense;
  final bool showDivider;

  const SettingsItemTile({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.iconColor,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.dense = false,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = SettingsVisuals.of(context);
    final resolvedIconColor = iconColor ?? visuals.accent;
    final hasAction = onTap != null;

    final tile = AnimatedContainer(
      duration: SettingsTokens.interactionDuration,
      curve: SettingsTokens.interactionCurve,
      constraints: BoxConstraints(
        minHeight: dense ? 60 : SettingsTokens.tileMinHeight,
      ),
      padding: padding,
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(color: visuals.divider),
              )
            : null,
      ),
      child: Row(
        children: [
          leading ??
              _SettingsIconBadge(
                icon: icon ?? Icons.settings_outlined,
                accentColor: resolvedIconColor,
                size: dense ? 38 : SettingsTokens.iconBadgeSize,
                iconSize: dense ? 18 : SettingsTokens.iconSize,
              ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  variant: AppTextVariant.body,
                  fontWeight: FontWeight.w600,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  AppText(
                    subtitle,
                    variant: AppTextVariant.caption,
                    color: visuals.secondaryText,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing ??
              (hasAction
                  ? _SettingsChevron(color: visuals.chevron)
                  : const SizedBox.shrink()),
        ],
      ),
    );

    if (!hasAction) {
      return tile;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SettingsTokens.tileRadius),
        onTap: onTap,
        child: tile,
      ),
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? accentColor;
  final bool showDivider;

  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.accentColor,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = SettingsVisuals.of(context);
    final resolvedAccent = accentColor ?? visuals.accent;

    return SettingsItemTile(
      icon: icon,
      iconColor: resolvedAccent,
      title: title,
      subtitle: subtitle,
      showDivider: showDivider,
      onTap: () => onChanged(!value),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: resolvedAccent,
      ),
    );
  }
}

class SegmentedModeSelector extends StatelessWidget {
  final ThemeMode selectedMode;
  final ValueChanged<ThemeMode> onChanged;
  final Map<ThemeMode, String> labels;

  const SegmentedModeSelector({
    super.key,
    required this.selectedMode,
    required this.onChanged,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = SettingsVisuals.of(context);
    const options = [
      (ThemeMode.light, Icons.light_mode_rounded),
      (ThemeMode.dark, Icons.dark_mode_rounded),
      (ThemeMode.system, Icons.phone_iphone_rounded),
    ];

    return SettingsGroupCard(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _ModeOption(
                selected: selectedMode == options[i].$1,
                label: labels[options[i].$1] ?? '',
                icon: options[i].$2,
                accent: visuals.accent,
                onTap: () => onChanged(options[i].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ThemePreviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final AppColors lightColors;
  final AppColors darkColors;

  const ThemePreviewCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.lightColors,
    required this.darkColors,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = SettingsVisuals.of(context);

    return AnimatedContainer(
      duration: SettingsTokens.interactionDuration,
      curve: SettingsTokens.interactionCurve,
      decoration: BoxDecoration(
        color: selected
            ? Color.alphaBlend(
                visuals.accent.withValues(alpha: 0.08),
                visuals.surface,
              )
            : visuals.surface,
        borderRadius: BorderRadius.circular(SettingsTokens.cardRadius),
        border: Border.all(
          color: selected
              ? visuals.accent.withValues(alpha: 0.68)
              : visuals.outline,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: visuals.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(SettingsTokens.cardRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                          const SizedBox(height: 4),
                          AppText(
                            subtitle,
                            variant: AppTextVariant.caption,
                            color: visuals.secondaryText,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    AnimatedOpacity(
                      duration: SettingsTokens.interactionDuration,
                      opacity: selected ? 1 : 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: visuals.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ThemeMiniPreview(
                        label: 'Light',
                        colors: lightColors,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ThemeMiniPreview(
                        label: 'Dark',
                        colors: darkColors,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsVisuals {
  final Color accent;
  final Color surface;
  final Color outline;
  final Color divider;
  final Color chevron;
  final Color secondaryText;
  final List<BoxShadow> cardShadow;

  const SettingsVisuals({
    required this.accent,
    required this.surface,
    required this.outline,
    required this.divider,
    required this.chevron,
    required this.secondaryText,
    required this.cardShadow,
  });

  factory SettingsVisuals.of(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accent = theme.colorScheme.primary;
    final surface = theme.cardColor;

    return SettingsVisuals(
      accent: accent,
      surface: surface,
      outline: brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.1)
          : const Color(0xFFDCE3EC),
      divider: brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.06),
      chevron: theme.colorScheme.onSurface.withValues(alpha: 0.34),
      secondaryText: theme.textTheme.bodyMedium?.color ??
          theme.colorScheme.onSurface.withValues(alpha: 0.72),
      cardShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: brightness == Brightness.dark ? 0.2 : 0.05,
          ),
          blurRadius: brightness == Brightness.dark ? 22 : 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

class _SettingsIconBadge extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final double size;
  final double iconSize;
  final double radius;

  const _SettingsIconBadge({
    required this.icon,
    required this.accentColor,
    this.size = SettingsTokens.iconBadgeSize,
    this.iconSize = SettingsTokens.iconSize,
    this.radius = SettingsTokens.iconRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accentColor.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.18 : 0.1),
          theme.cardColor,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: accentColor, size: iconSize),
    );
  }
}

class _SettingsChevron extends StatelessWidget {
  final Color color;

  const _SettingsChevron({required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.arrow_forward_ios_rounded,
      size: 15,
      color: color,
    );
  }
}

class _ModeOption extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _ModeOption({
    required this.selected,
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: SettingsTokens.interactionDuration,
          curve: SettingsTokens.interactionCurve,
          height: 48,
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(
                    accent.withValues(alpha: 0.16),
                    theme.cardColor,
                  )
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.36)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? accent
                    : theme.colorScheme.onSurface.withValues(alpha: 0.68),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: AppText(
                  label,
                  variant: AppTextVariant.caption,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? accent
                      : theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeMiniPreview extends StatelessWidget {
  final String label;
  final AppColors colors;

  const _ThemeMiniPreview({
    required this.label,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            label,
            variant: AppTextVariant.caption,
            color: colors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 10),
          Container(
            height: 10,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, colors.secondary],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.textPrimary.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.textSecondary.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
