import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageNotifier extends StateNotifier<Locale> {
  LanguageNotifier() : super(const Locale('ar', '')) {
    _loadLanguage();
  }

  static const String _languageKey = 'selected_language';

  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_languageKey);
      
      if (languageCode != null) {
        state = Locale(languageCode, '');
      } else {
        // Default to Arabic if no preference is stored
        state = const Locale('ar', '');
      }
    } catch (e) {
      // Keep default Arabic
      state = const Locale('ar', '');
    }
  }

  Future<void> setLanguage(Locale locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, locale.languageCode);
      state = locale;
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> toggleLanguage() async {
    final newLocale = state.languageCode == 'en' 
        ? const Locale('ar', '') 
        : const Locale('en', '');
    await setLanguage(newLocale);
  }

  bool get isArabic => state.languageCode == 'ar';
  bool get isEnglish => state.languageCode == 'en';
}

final languageProviderRiverpod = StateNotifierProvider<LanguageNotifier, Locale>((ref) {
  return LanguageNotifier();
});
