import 'package:flutter/material.dart';

Route<T> buildSettingsRoute<T>(Widget page) {
  return MaterialPageRoute<T>(
    builder: (_) => page,
  );
}

Future<T?> pushSettingsRoute<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(buildSettingsRoute<T>(page));
}
