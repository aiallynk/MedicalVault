import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../localization/app_localizations.dart';
import '../services/app_update_service.dart';
import '../widgets/app_text.dart';
import '../widgets/settings_primitives.dart';

class AboutAppPage extends StatefulWidget {
  const AboutAppPage({super.key});

  @override
  State<AboutAppPage> createState() => _AboutAppPageState();
}

class _AboutAppPageState extends State<AboutAppPage> {
  final AppUpdateService _updateService = AppUpdateService();
  PackageInfo? _packageInfo;
  AppUpdateCheckResult? _checkResult;
  bool _checking = false;
  bool _updating = false;
  double _downloadProgress = 0;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await _updateService.getPackageInfo();
    if (!mounted) return;
    setState(() {
      _packageInfo = packageInfo;
    });
  }

  Future<void> _checkLatestUpdate() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _statusMessage = null;
    });

    final result = await _updateService.checkForUpdate(ignoreSkipWindow: true);
    if (!mounted) return;
    setState(() {
      _checkResult = result;
      _checking = false;
      _statusMessage = result.error;
    });
  }

  Future<void> _triggerUpdate() async {
    final info = _checkResult?.info;
    if (info == null || _updating) return;

    setState(() {
      _updating = true;
      _downloadProgress = 0;
      _statusMessage = null;
    });

    final installResult = await _updateService.downloadAndInstallUpdate(
      info: info,
      onProgress: (progress) {
        if (!mounted) return;
        setState(() {
          _downloadProgress = progress.clamp(0, 1);
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _updating = false;
      _statusMessage = installResult.message;
    });

    if (installResult.installCompleted) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final visuals = SettingsVisuals.of(context);
    final info = _checkResult?.info;
    final hasUpdate = _checkResult?.hasUpdate == true;

    return Scaffold(
      appBar: AppBar(
        title: AppText(
          l10n.t('about.title'),
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
              title: l10n.t('about.title'),
              subtitle: l10n.t('about.pageSubtitle'),
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: SettingsTokens.sectionGap),
            SettingsSection(
              title: l10n.t('about.identitySectionTitle'),
              subtitle: l10n.t('about.identitySectionSubtitle'),
              child: SettingsGroupCard(
                child: Column(
                  children: [
                    _InfoTile(
                      title: l10n.t('about.field.appName'),
                      value: l10n.auto('Medical Vault'),
                      showDivider: true,
                    ),
                    _InfoTile(
                      title: l10n.t('about.field.package'),
                      value: _packageInfo?.packageName ?? '-',
                      showDivider: true,
                    ),
                    _InfoTile(
                      title: l10n.t('about.field.version'),
                      value: _packageInfo == null
                          ? '-'
                          : '${_packageInfo!.version} (${_packageInfo!.buildNumber})',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SettingsTokens.sectionGap),
            SettingsSection(
              title: l10n.t('about.updatesSectionTitle'),
              subtitle: l10n.t('about.updatesSectionSubtitle'),
              trailing: FilledButton.tonalIcon(
                onPressed: _checking ? null : _checkLatestUpdate,
                icon: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.system_update_alt_rounded),
                label: Text(l10n.t('about.checkLatest')),
              ),
              child: _GlassUpdateCard(
                accent: visuals.accent,
                child: Column(
                  children: [
                    _InfoTile(
                      title: l10n.t('update.field.current'),
                      value: _checkResult?.currentVersion ??
                          _packageInfo?.version ??
                          '-',
                      showDivider: info != null,
                    ),
                    if (info != null) ...[
                      _InfoTile(
                        title: l10n.t('update.field.latest'),
                        value: info.latestVersion,
                        showDivider: true,
                      ),
                      _InfoTile(
                        title: l10n.t('update.field.minimumSupported'),
                        value: info.minimumSupportedVersion,
                        showDivider: info.releaseNotes.isNotEmpty,
                      ),
                    ],
                    if (info != null && info.releaseNotes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              l10n.t('about.releaseNotes'),
                              variant: AppTextVariant.body,
                              fontWeight: FontWeight.w700,
                            ),
                            const SizedBox(height: 8),
                            AppText(
                              info.releaseNotes,
                              variant: AppTextVariant.caption,
                              color: visuals.secondaryText,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_checkResult != null && !hasUpdate)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    visuals.accent.withValues(alpha: 0.12),
                    visuals.surface,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: visuals.accent.withValues(alpha: 0.2),
                  ),
                ),
                child: AppText(
                  l10n.t('about.upToDate'),
                  variant: AppTextVariant.caption,
                  color: visuals.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (hasUpdate && info != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _updating ? null : _triggerUpdate,
                icon: _updating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(
                  _updating
                      ? '${l10n.t('update.action.updateNow')}...'
                      : l10n.t('update.action.updateNow'),
                ),
              ),
            ],
            if (_updating) ...[
              const SizedBox(height: 12),
              SettingsGroupCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: _downloadProgress),
                    const SizedBox(height: 8),
                    AppText(
                      '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                      variant: AppTextVariant.caption,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ],
                ),
              ),
            ],
            if (_statusMessage != null && _statusMessage!.isNotEmpty) ...[
              const SizedBox(height: 12),
              SettingsGroupCard(
                padding: const EdgeInsets.all(16),
                child: AppText(
                  _statusMessage!,
                  variant: AppTextVariant.caption,
                  color: visuals.secondaryText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GlassUpdateCard extends StatelessWidget {
  final Widget child;
  final Color accent;

  const _GlassUpdateCard({
    required this.child,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(SettingsTokens.groupRadius),
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: const SizedBox.expand(),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    Colors.white.withValues(alpha: isDark ? 0.14 : 0.62),
                    theme.cardColor,
                  ),
                  Color.alphaBlend(
                    accent.withValues(alpha: isDark ? 0.18 : 0.09),
                    theme.cardColor,
                  ),
                ],
              ),
              borderRadius: BorderRadius.circular(SettingsTokens.groupRadius),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.68),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -26,
                  right: -12,
                  child: IgnorePointer(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accent.withValues(alpha: isDark ? 0.22 : 0.2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;
  final bool showDivider;

  const _InfoTile({
    required this.title,
    required this.value,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = SettingsVisuals.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(color: visuals.divider),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppText(
              title,
              variant: AppTextVariant.caption,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AppText(
              value,
              variant: AppTextVariant.caption,
              color: visuals.secondaryText,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
