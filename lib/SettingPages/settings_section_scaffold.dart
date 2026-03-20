import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/app_text.dart';
import '../widgets/settings_primitives.dart';

class SettingsSectionScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final ValueListenable<int> refreshListenable;
  final WidgetBuilder contentBuilder;

  const SettingsSectionScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.refreshListenable,
    required this.contentBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
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
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                SettingsTokens.pageHorizontal,
                12,
                SettingsTokens.pageHorizontal,
                SettingsTokens.pageBottom,
              ),
              children: [
                SettingsPageHeader(
                  title: title,
                  subtitle: subtitle,
                  icon: _iconForTitle(title),
                ),
                const SizedBox(height: SettingsTokens.sectionGap),
                contentBuilder(context),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData _iconForTitle(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('profile')) return Icons.badge_outlined;
    if (normalized.contains('security')) return Icons.lock_outline_rounded;
    if (normalized.contains('health')) {
      return Icons.health_and_safety_outlined;
    }
    if (normalized.contains('preference')) return Icons.tune_rounded;
    if (normalized.contains('notification')) {
      return Icons.notifications_active_outlined;
    }
    if (normalized.contains('privacy') || normalized.contains('help')) {
      return Icons.verified_user_outlined;
    }
    if (normalized.contains('account')) return Icons.logout_rounded;
    return Icons.settings_rounded;
  }
}
