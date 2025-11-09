import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_localizations.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _localeKey = 'app_locale';

  Locale _locale;

  LanguageProvider(this._locale);

  Locale get locale => _locale;

  static Future<Locale> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_localeKey);
    if (saved == null || saved.isEmpty) {
      return const Locale('en');
    }
    final candidate = Locale(saved);
    final supported = AppLocalizations.supportedLocales
        .map((e) => e.languageCode)
        .contains(candidate.languageCode);
    return supported ? candidate : const Locale('en');
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    if (!_isSupported(locale)) return;
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
    notifyListeners();
  }

  bool _isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .map((e) => e.languageCode)
        .contains(locale.languageCode);
  }
}

