import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'settings_section_scaffold.dart';

class NotificationsSettingsPage extends StatelessWidget {
  final ValueListenable<int> refreshListenable;
  final WidgetBuilder contentBuilder;
  final String title;
  final String subtitle;

  const NotificationsSettingsPage({
    super.key,
    required this.refreshListenable,
    required this.contentBuilder,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsSectionScaffold(
      title: title,
      subtitle: subtitle,
      refreshListenable: refreshListenable,
      contentBuilder: contentBuilder,
    );
  }
}
