import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hello/core/theme/theme.dart';
import 'package:hello/providers/language_provider.dart';

void main() {
  testWidgets('provider-aware app bootstrap renders', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => ThemeProvider(
              themeMode: ThemeMode.light,
              palette: AppThemePalette.teal,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => LanguageProvider(const Locale('en')),
          ),
        ],
        child: Builder(
          builder: (context) {
            final themeProvider = context.watch<ThemeProvider>();
            final languageProvider = context.watch<LanguageProvider>();
            return MaterialApp(
              theme: themeProvider.lightTheme,
              darkTheme: themeProvider.darkTheme,
              themeMode: themeProvider.themeMode,
              locale: languageProvider.locale,
              home: const Scaffold(
                body: Center(
                  child: Text('Bootstrap Ready'),
                ),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Bootstrap Ready'), findsOneWidget);
  });
}
