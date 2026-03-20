import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/theme.dart';
import '../widgets/app_text.dart';
import '../widgets/settings_primitives.dart';

class PreferencesSettingsPage extends StatelessWidget {
  final ValueListenable<int> refreshListenable;
  final WidgetBuilder contentBuilder;
  final String title;
  final String subtitle;

  const PreferencesSettingsPage({
    super.key,
    required this.refreshListenable,
    required this.contentBuilder,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = SettingsVisuals.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final modeLabel = switch (themeProvider.themeMode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };
    final accentLabel = themeProvider.customPrimaryColor == null
        ? appThemePaletteLabel(themeProvider.palette)
        : (themeProvider.hasCustomGradient
            ? 'Custom Gradient'
            : 'Custom Solid');
    final gradientColors = AppThemes.primaryGradient(
      themeProvider.palette,
      theme.brightness,
      customPrimaryColor: themeProvider.customPrimaryColor,
      customSecondaryColor: themeProvider.customSecondaryColor,
    );

    return Scaffold(
      appBar: AppBar(
        title: AppText(
          title,
          variant: AppTextVariant.subtitle,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: refreshListenable,
          builder: (context, _, __) {
            return ListView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                SettingsTokens.pageHorizontal,
                12,
                SettingsTokens.pageHorizontal,
                SettingsTokens.pageBottom,
              ),
              children: [
                _PreferencesHero(
                  title: title,
                  subtitle: subtitle,
                  modeLabel: modeLabel,
                  accentLabel: accentLabel,
                  gradientColors: gradientColors,
                ),
                const SizedBox(height: SettingsTokens.sectionGap),
                Container(
                  decoration: BoxDecoration(
                    color: visuals.surface,
                    borderRadius:
                        BorderRadius.circular(SettingsTokens.cardRadius),
                    border: Border.all(color: visuals.outline),
                    boxShadow: visuals.cardShadow,
                  ),
                  padding: const EdgeInsets.all(14),
                  child: contentBuilder(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PreferencesHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final String modeLabel;
  final String accentLabel;
  final List<Color> gradientColors;

  const _PreferencesHero({
    required this.title,
    required this.subtitle,
    required this.modeLabel,
    required this.accentLabel,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors.length >= 2
              ? gradientColors.take(2).toList()
              : [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(SettingsTokens.cardRadius),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -16,
            child: IgnorePointer(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.35),
                      Colors.white.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  variant: AppTextVariant.subtitle,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                const SizedBox(height: 4),
                AppText(
                  subtitle,
                  variant: AppTextVariant.caption,
                  color: Colors.white.withValues(alpha: 0.9),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _HeroPill(
                        icon: Icons.palette_outlined,
                        label: accentLabel,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroPill(
                        icon: Icons.dark_mode_outlined,
                        label: modeLabel,
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

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: AppText(
              label,
              variant: AppTextVariant.caption,
              color: Colors.white,
              fontWeight: FontWeight.w700,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
