import 'package:flutter/material.dart';

class LocaleProvider with ChangeNotifier {
  Locale _locale = const Locale('en', 'US');

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    if (_locale == locale) return;

    _locale = locale;
    notifyListeners();
  }
  
  void clearLocale() {
    _locale = const Locale('en', 'US');
    notifyListeners();
  }
  
  bool get isEnglish => _locale.languageCode == 'en';
  bool get isArabic => _locale.languageCode == 'ar';
  bool get isFrench => _locale.languageCode == 'fr';

  String get languageCode => _locale.languageCode;
  String get countryCode => _locale.countryCode ?? '';

  static List<Locale> get supportedLocales => const [
        Locale('en', 'US'),
        Locale('ar', 'SA'),
        Locale('fr', 'FR'),
      ];

  static List<String> get supportedLanguageCodes => ['en', 'ar', 'fr'];

  String getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'ar':
        return 'العربية';
      case 'fr':
        return 'Français';
      default:
        return 'English';
    }
  }
  
  String getCurrentLanguageName() {
    return getLanguageName(_locale.languageCode);
  }
}
