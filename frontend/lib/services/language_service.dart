import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static const String _languageKey = 'selected_language';
  
  static Future<String> getSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'en';
  }
  
  static Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }
  
  // Alias for saveLanguage for backwards compatibility
  static Future<void> setLanguage(String languageCode) async {
    await saveLanguage(languageCode);
  }

  static Future<Locale> getSavedLocale() async {
    final languageCode = await getSavedLanguage();
    return getLocaleFromLanguageCode(languageCode);
  }
  
  static Locale getLocaleFromLanguageCode(String languageCode) {
    switch (languageCode) {
      case 'ar':
        return const Locale('ar', 'SA');
      case 'fr':
        return const Locale('fr', 'FR');
      case 'en':
      default:
        return const Locale('en', 'US');
    }
  }
  
  static List<Locale> getSupportedLocales() {
    return const [
      Locale('en', 'US'),
      Locale('ar', 'SA'),
      Locale('fr', 'FR'),
    ];
  }
  
  static List<String> getSupportedLanguageCodes() {
    return ['en', 'ar', 'fr'];
  }

  static String getLanguageDisplayName(String languageCode) {
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

  static String getLanguageNativeName(String languageCode) {
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

  static bool isRTL(String languageCode) {
    return languageCode == 'ar';
  }

  static TextDirection getTextDirection(String languageCode) {
    return isRTL(languageCode) ? TextDirection.rtl : TextDirection.ltr;
  }
}
