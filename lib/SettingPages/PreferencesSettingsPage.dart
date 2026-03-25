import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
