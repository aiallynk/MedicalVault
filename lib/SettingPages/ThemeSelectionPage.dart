import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/theme.dart';
import '../localization/app_localizations.dart';
import '../widgets/app_text.dart';
import '../widgets/settings_primitives.dart';

class ThemeSelectionPage extends StatelessWidget {
  const ThemeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final l10n = context.l10n;
    final customColor =
        themeProvider.customPrimaryColor ?? theme.colorScheme.primary;
    final customSecondaryColor = themeProvider.customSecondaryColor;

    return Scaffold(
      appBar: AppBar(
        title: AppText(
          l10n.auto('Theme Style'),
          variant: AppTextVariant.subtitle,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SettingsTokens.pageHorizontal,
            12,
            SettingsTokens.pageHorizontal,
            SettingsTokens.pageBottom,
          ),
          children: [
            SettingsPageHeader(
              title: l10n.auto('Theme Style'),
              subtitle: l10n.auto(
                'Compare palettes, preview light and dark surfaces, and fine-tune the app accent.',
              ),
              icon: Icons.palette_outlined,
            ),
            const SizedBox(height: SettingsTokens.sectionGap),
            SettingsSection(
              title: l10n.auto('Theme Preview'),
              subtitle: l10n.auto(
                'Each option shows a compact preview for both light and dark presentation.',
              ),
              child: Column(
                children: [
                  for (final palette in AppThemePalette.values) ...[
                    ThemePreviewCard(
                      title: appThemePaletteLabel(palette),
                      subtitle: _themeDescription(l10n, palette),
                      selected: themeProvider.palette == palette,
                      onTap: () => themeProvider.setPalette(palette),
                      lightColors: AppThemes.colorsFor(
                        palette,
                        Brightness.light,
                        customPrimaryColor: customColor,
                        customSecondaryColor: customSecondaryColor,
                      ),
                      darkColors: AppThemes.colorsFor(
                        palette,
                        Brightness.dark,
                        customPrimaryColor: customColor,
                        customSecondaryColor: customSecondaryColor,
                      ),
                    ),
                    if (palette != AppThemePalette.values.last)
                      const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: SettingsTokens.sectionGap),
            SettingsSection(
              title: l10n.auto('Mode'),
              subtitle: l10n.auto(
                'Pick the appearance behavior that feels best on your device.',
              ),
              child: SegmentedModeSelector(
                selectedMode: themeProvider.themeMode,
                onChanged: themeProvider.setThemeMode,
                labels: {
                  ThemeMode.light: l10n.auto('Light'),
                  ThemeMode.dark: l10n.auto('Dark'),
                  ThemeMode.system: l10n.auto('System'),
                },
              ),
            ),
            const SizedBox(height: SettingsTokens.sectionGap),
            SettingsSection(
              title: l10n.auto('Custom Accent'),
              subtitle: l10n.auto(
                'Create a custom color profile or reset back to the default palette.',
              ),
              child: Column(
                children: [
                  SettingsGroupCard(
                    child: Column(
                      children: [
                        SettingsItemTile(
                          icon: Icons.color_lens_outlined,
                          title: l10n.auto('Create Custom Color'),
                          subtitle: l10n.auto(
                            'Adjust red, green and blue values to create a personalized accent.',
                          ),
                          onTap: () => _showCustomColorDialog(context),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ColorSwatch(
                                color: customColor,
                                secondaryColor: customSecondaryColor,
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 15,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.34),
                              ),
                            ],
                          ),
                        ),
                        if (themeProvider.customPrimaryColor != null)
                          SettingsItemTile(
                            icon: Icons.restore_rounded,
                            title: l10n.auto('Reset Custom Color'),
                            subtitle: l10n.auto(
                              'Return to the default teal palette while keeping the rest of your preferences.',
                            ),
                            iconColor: theme.colorScheme.error,
                            onTap: () async {
                              await themeProvider.clearCustomPrimaryColor();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.auto(
                                        'Custom theme color reset to default'),
                                  ),
                                ),
                              );
                            },
                            showDivider: false,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildAccentPresetSection(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _themeDescription(AppLocalizations l10n, AppThemePalette palette) {
    switch (palette) {
      case AppThemePalette.teal:
        return l10n
            .auto('Fresh clinical greens with softer, calming contrast.');
      case AppThemePalette.purple:
        return l10n.auto('Modern indigo tones with vibrant highlights.');
      case AppThemePalette.custom:
        return l10n.auto('Your personalized color translated across the app.');
    }
  }

  Future<void> _showCustomColorDialog(BuildContext context) async {
    final themeProvider = context.read<ThemeProvider>();
    Color selected = themeProvider.customPrimaryColor ??
        Theme.of(context).colorScheme.primary;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(context.l10n.auto('Create Custom Color')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: selected,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildColorSlider(
                      context,
                      label: 'R',
                      value: (selected.r * 255).round().toDouble(),
                      activeColor: Colors.red,
                      onChanged: (value) => setLocalState(() {
                        final g = (selected.g * 255).round();
                        final b = (selected.b * 255).round();
                        selected = Color.fromARGB(
                          255,
                          value.round(),
                          g,
                          b,
                        );
                      }),
                    ),
                    _buildColorSlider(
                      context,
                      label: 'G',
                      value: (selected.g * 255).round().toDouble(),
                      activeColor: Colors.green,
                      onChanged: (value) => setLocalState(() {
                        final r = (selected.r * 255).round();
                        final b = (selected.b * 255).round();
                        selected = Color.fromARGB(
                          255,
                          r,
                          value.round(),
                          b,
                        );
                      }),
                    ),
                    _buildColorSlider(
                      context,
                      label: 'B',
                      value: (selected.b * 255).round().toDouble(),
                      activeColor: Colors.blue,
                      onChanged: (value) => setLocalState(() {
                        final r = (selected.r * 255).round();
                        final g = (selected.g * 255).round();
                        selected = Color.fromARGB(
                          255,
                          r,
                          g,
                          value.round(),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.l10n.auto('Cancel')),
                ),
                TextButton(
                  onPressed: () async {
                    await themeProvider.setCustomPrimaryColor(selected);
                    if (!context.mounted) return;
                    Navigator.pop(dialogContext);
                  },
                  child: Text(context.l10n.auto('Apply')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAccentPresetSection(BuildContext context) {
    final l10n = context.l10n;
    final themeProvider = context.watch<ThemeProvider>();
    final presets = _AccentPreset.all;

    return SettingsSection(
      title: l10n.auto('Preset Accent Packs'),
      subtitle: l10n.auto(
        'Use 4 solid accents and 4 gradient accents with a soft shine effect.',
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: presets.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
        ),
        itemBuilder: (context, index) {
          final preset = presets[index];
          final selected = _isPresetSelected(themeProvider, preset);
          return _AccentPresetCard(
            preset: preset,
            selected: selected,
            onTap: () async {
              if (preset.isGradient) {
                await themeProvider.setCustomGradientColors(
                  primary: preset.primary,
                  secondary: preset.secondary!,
                );
              } else {
                await themeProvider.setCustomPrimaryColor(preset.primary);
              }
            },
          );
        },
      ),
    );
  }

  bool _isPresetSelected(ThemeProvider provider, _AccentPreset preset) {
    final primary = provider.customPrimaryColor;
    final secondary = provider.customSecondaryColor;
    if (!_sameColor(primary, preset.primary)) return false;
    if (!preset.isGradient) return secondary == null;
    return _sameColor(secondary, preset.secondary);
  }

  bool _sameColor(Color? a, Color? b) {
    if (a == null || b == null) return false;
    return _toColorValue(a) == _toColorValue(b);
  }

  int _toColorValue(Color color) {
    final a = (color.a * 255).round() & 0xFF;
    final r = (color.r * 255).round() & 0xFF;
    final g = (color.g * 255).round() & 0xFF;
    final b = (color.b * 255).round() & 0xFF;
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  Widget _buildColorSlider(
    BuildContext context, {
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    required Color activeColor,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: AppText(
            label,
            variant: AppTextVariant.caption,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 255,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final Color? secondaryColor;

  const _ColorSwatch({required this.color, this.secondaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: secondaryColor == null ? color : null,
        gradient: secondaryColor == null
            ? null
            : LinearGradient(
                colors: [color, secondaryColor!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
    );
  }
}

class _AccentPreset {
  final String label;
  final Color primary;
  final Color? secondary;

  const _AccentPreset.solid({
    required this.label,
    required this.primary,
  }) : secondary = null;

  const _AccentPreset.gradient({
    required this.label,
    required this.primary,
    required this.secondary,
  });

  bool get isGradient => secondary != null;

  static const List<_AccentPreset> all = [
    _AccentPreset.solid(
      label: 'Forest',
      primary: Color(0xFF0F9D94),
    ),
    _AccentPreset.solid(
      label: 'Royal',
      primary: Color(0xFF3759F3),
    ),
    _AccentPreset.solid(
      label: 'Coral',
      primary: Color(0xFFE85D5D),
    ),
    _AccentPreset.solid(
      label: 'Sunset',
      primary: Color(0xFFE29B17),
    ),
    _AccentPreset.gradient(
      label: 'Aqua Shine',
      primary: Color(0xFF0EA5E9),
      secondary: Color(0xFF22D3EE),
    ),
    _AccentPreset.gradient(
      label: 'Berry Glow',
      primary: Color(0xFF7C3AED),
      secondary: Color(0xFFE11D9B),
    ),
    _AccentPreset.gradient(
      label: 'Aurora',
      primary: Color(0xFF16A34A),
      secondary: Color(0xFF14B8A6),
    ),
    _AccentPreset.gradient(
      label: 'Firelight',
      primary: Color(0xFFF97316),
      secondary: Color(0xFFEF4444),
    ),
  ];
}

class _AccentPresetCard extends StatelessWidget {
  final _AccentPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _AccentPresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseGradient = preset.isGradient
        ? [preset.primary, preset.secondary!]
        : [
            Color.alphaBlend(
              preset.primary.withValues(alpha: 0.15),
              theme.cardColor,
            ),
            Color.alphaBlend(
              preset.primary.withValues(alpha: 0.08),
              theme.cardColor,
            ),
          ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SettingsTokens.groupRadius),
        onTap: onTap,
        child: AnimatedContainer(
          duration: SettingsTokens.interactionDuration,
          curve: SettingsTokens.interactionCurve,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: baseGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(SettingsTokens.groupRadius),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.8)
                  : theme.dividerColor.withValues(alpha: 0.6),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.2 : 0.06,
                ),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (preset.isGradient)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.34),
                            Colors.white.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.18, 0.5],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius:
                            BorderRadius.circular(SettingsTokens.groupRadius),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      preset.label,
                      variant: AppTextVariant.caption,
                      fontWeight: FontWeight.w700,
                      color: preset.isGradient
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: preset.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        if (preset.secondary != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: preset.secondary!,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: preset.isGradient
                              ? Colors.white
                              : theme.colorScheme.primary,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
