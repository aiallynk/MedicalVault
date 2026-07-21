import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/theme.dart';

class ThemeSelectionPage extends StatelessWidget {
  const ThemeSelectionPage({super.key});

  static const List<_AccentOption> _accentOptions = [
    _AccentOption(
      label: 'Teal',
      palette: AppThemePalette.teal,
      color: Color(0xFF14B8A6),
    ),
    _AccentOption(
      label: 'Blue',
      palette: AppThemePalette.softBlue,
      color: Color(0xFF3B82F6),
    ),
    _AccentOption(
      label: 'Indigo',
      palette: AppThemePalette.indigo,
      color: Color(0xFF6366F1),
    ),
    _AccentOption(
      label: 'Green',
      palette: AppThemePalette.emerald,
      color: Color(0xFF22C55E),
    ),
    _AccentOption(
      label: 'Gray',
      palette: AppThemePalette.warmGray,
      color: Color(0xFF94A3B8),
    ),
    _AccentOption(
      label: 'Purple',
      palette: AppThemePalette.mutedPurple,
      color: Color(0xFF8B5CF6),
    ),
    _AccentOption(
      label: 'Orange',
      palette: AppThemePalette.softOrange,
      color: Color(0xFFF59E0B),
    ),
    _AccentOption(
      label: 'Pink',
      palette: AppThemePalette.softRose,
      color: Color(0xFFEC4899),
    ),
  ];

  static const List<_GradientOption> _gradientOptions = [
    _GradientOption(
      label: 'Aqua Shield',
      start: AppDefaultTheme.gradientStart,
      end: AppDefaultTheme.gradientEnd,
    ),
    _GradientOption(
      label: 'Clinical Sky',
      start: Color(0xFF2287F2),
      end: Color(0xFF68C3FF),
    ),
    _GradientOption(
      label: 'Indigo Flow',
      start: Color(0xFF4E63E8),
      end: Color(0xFF8E83FF),
    ),
    _GradientOption(
      label: 'Emerald Calm',
      start: Color(0xFF14A678),
      end: Color(0xFF57D7AA),
    ),
    _GradientOption(
      label: 'Slate Trust',
      start: Color(0xFF748499),
      end: Color(0xFFB4C0CE),
    ),
    _GradientOption(
      label: 'Violet Care',
      start: Color(0xFF7A64D1),
      end: Color(0xFFB193EA),
    ),
    _GradientOption(
      label: 'Warm Pulse',
      start: Color(0xFFD9873E),
      end: Color(0xFFF3B766),
    ),
    _GradientOption(
      label: 'Rose Sync',
      start: Color(0xFFBC6580),
      end: Color(0xFFE5A6BE),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final selectedSolidPalette = _selectedSolidPalette(themeProvider);
    final resolvedPrimary = _resolvedPrimaryColor(themeProvider);
    final resolvedSecondary = themeProvider.customSecondaryColor;
    final colors = _StudioColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const _PageHeader(
              title: 'Theme Studio',
              subtitle:
                  'Choose the theme mode, accent color, and preview how the app will look in light or dark mode.',
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Theme Mode',
              subtitle:
                  'Choose how the app looks throughout the day on your device.',
              child: Row(
                children: [
                  Expanded(
                    child: _ModeChip(
                      label: 'Light',
                      selected: themeProvider.themeMode == ThemeMode.light,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ModeChip(
                      label: 'Dark',
                      selected: themeProvider.themeMode == ThemeMode.dark,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ModeChip(
                      label: 'System',
                      selected: themeProvider.themeMode == ThemeMode.system,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Accent Color',
              subtitle:
                  'Pick the accent used for buttons, highlights, toggles, and progress.',
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _accentOptions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.78,
                ),
                itemBuilder: (context, index) {
                  final option = _accentOptions[index];
                  return _AccentSwatch(
                    label: option.label,
                    color: option.color,
                    selected: selectedSolidPalette == option.palette,
                    onTap: () => themeProvider.setPalette(option.palette),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              child: _AccentPreviewStrip(
                primary: resolvedPrimary,
                secondary: resolvedSecondary,
              ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Gradient Accent',
              subtitle:
                  'Choose a soft two-tone accent for buttons and highlighted actions.',
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _gradientOptions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.15,
                ),
                itemBuilder: (context, index) {
                  final option = _gradientOptions[index];
                  return _GradientOptionTile(
                    label: option.label,
                    start: option.start,
                    end: option.end,
                    selected: _isGradientSelected(themeProvider, option),
                    onTap: () => themeProvider.setCustomGradientColors(
                      primary: option.start,
                      secondary: option.end,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Live Preview',
              child: _LivePreviewCard(
                primary: resolvedPrimary,
                secondary: resolvedSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppThemePalette? _selectedSolidPalette(ThemeProvider provider) {
    if (provider.palette != AppThemePalette.custom) {
      return provider.palette;
    }

    if (provider.customSecondaryColor != null) {
      return null;
    }

    final customPrimary = provider.customPrimaryColor;
    for (final option in _accentOptions) {
      if (_sameColor(customPrimary, option.color)) {
        return option.palette;
      }
    }
    return null;
  }

  Color _resolvedPrimaryColor(ThemeProvider provider) {
    if (provider.customPrimaryColor != null) {
      return provider.customPrimaryColor!;
    }

    for (final option in _accentOptions) {
      if (option.palette == provider.palette) {
        return option.color;
      }
    }

    return _accentOptions.first.color;
  }

  bool _isGradientSelected(ThemeProvider provider, _GradientOption option) {
    return _sameColor(provider.customPrimaryColor, option.start) &&
        _sameColor(provider.customSecondaryColor, option.end);
  }

  bool _sameColor(Color? a, Color? b) {
    if (a == null || b == null) {
      return false;
    }

    return _colorValue(a) == _colorValue(b);
  }

  int _colorValue(Color color) {
    final alpha = (color.a * 255).round() & 0xFF;
    final red = (color.r * 255).round() & 0xFF;
    final green = (color.g * 255).round() & 0xFF;
    final blue = (color.b * 255).round() & 0xFF;
    return (alpha << 24) | (red << 16) | (green << 8) | blue;
  }
}

class _PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PageHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _StudioColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.title,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.subtitle,
                height: 1.45,
              ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _StudioColors.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((title ?? '').trim().isNotEmpty) ...[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.title,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if ((subtitle ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.subtitle,
                      height: 1.45,
                    ),
              ),
            ],
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _StudioColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: selected ? colors.selectedFill : colors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? colors.selectedBorder : colors.unselectedBorder,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected ? colors.selectedText : colors.title,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _AccentSwatch({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _StudioColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      selected ? colors.selectedText : colors.unselectedBorder,
                  width: selected ? 2 : 1,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.title,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentPreviewStrip extends StatelessWidget {
  final Color primary;
  final Color? secondary;

  const _AccentPreviewStrip({
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _StudioColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: colors.stripBackground,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 140,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              width: 52,
              height: 30,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.centerRight,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: secondary == null ? primary : null,
                  gradient: secondary == null
                      ? null
                      : LinearGradient(
                          colors: [primary, secondary!],
                        ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Button Preview',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GradientOptionTile extends StatelessWidget {
  final String label;
  final Color start;
  final Color end;
  final bool selected;
  final VoidCallback onTap;

  const _GradientOptionTile({
    required this.label,
    required this.start,
    required this.end,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [start, end],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected ? Colors.white : Colors.white.withValues(alpha: 0.6),
              width: selected ? 2 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x160F172A),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              _RadioIndicator(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioIndicator extends StatelessWidget {
  final bool selected;

  const _RadioIndicator({required this.selected});

  @override
  Widget build(BuildContext context) {
    final colors = _StudioColors.of(context);

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors.selectedText,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

class _LivePreviewCard extends StatelessWidget {
  final Color primary;
  final Color? secondary;

  const _LivePreviewCard({
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _StudioColors.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.favorite_outline_rounded,
                    color: primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 10,
                        width: 110,
                        decoration: BoxDecoration(
                          color: colors.lineStrong,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 8,
                        width: 150,
                        decoration: BoxDecoration(
                          color: colors.lineSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: secondary == null ? primary : null,
              gradient: secondary == null
                  ? null
                  : LinearGradient(
                      colors: [primary, secondary!],
                    ),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Primary Button',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioColors {
  final Color background;
  final Color cardBackground;
  final Color cardBorder;
  final Color title;
  final Color subtitle;
  final Color selectedFill;
  final Color selectedBorder;
  final Color selectedText;
  final Color unselectedBorder;
  final Color stripBackground;
  final Color surfaceSoft;
  final Color lineStrong;
  final Color lineSoft;
  final Color shadow;

  const _StudioColors({
    required this.background,
    required this.cardBackground,
    required this.cardBorder,
    required this.title,
    required this.subtitle,
    required this.selectedFill,
    required this.selectedBorder,
    required this.selectedText,
    required this.unselectedBorder,
    required this.stripBackground,
    required this.surfaceSoft,
    required this.lineStrong,
    required this.lineSoft,
    required this.shadow,
  });

  factory _StudioColors.of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;

    return _StudioColors(
      background: theme.scaffoldBackgroundColor,
      cardBackground: theme.cardColor,
      cardBorder: isDark
          ? Colors.white.withValues(alpha: 0.10)
          : const Color(0xFFE5E7EB),
      title: onSurface,
      subtitle: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
      selectedFill: Color.alphaBlend(
        primary.withValues(alpha: isDark ? 0.22 : 0.12),
        theme.cardColor,
      ),
      selectedBorder: primary.withValues(alpha: isDark ? 0.55 : 0.35),
      selectedText: primary,
      unselectedBorder: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : const Color(0xFFD6DCE5),
      stripBackground: isDark
          ? Colors.white.withValues(alpha: 0.10)
          : const Color(0xFFE5E7EB),
      surfaceSoft: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      lineStrong: isDark
          ? Colors.white.withValues(alpha: 0.30)
          : const Color(0xFFCBD5E1),
      lineSoft: isDark
          ? Colors.white.withValues(alpha: 0.18)
          : const Color(0xFFE2E8F0),
      shadow: isDark
          ? Colors.black.withValues(alpha: 0.24)
          : const Color(0x140F172A),
    );
  }
}

class _AccentOption {
  final String label;
  final AppThemePalette palette;
  final Color color;

  const _AccentOption({
    required this.label,
    required this.palette,
    required this.color,
  });
}

class _GradientOption {
  final String label;
  final Color start;
  final Color end;

  const _GradientOption({
    required this.label,
    required this.start,
    required this.end,
  });
}
