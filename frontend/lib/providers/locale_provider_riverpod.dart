import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/language_service.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en', 'US')) {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final savedLocale = await LanguageService.getSavedLocale();
    state = savedLocale;
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await LanguageService.setLanguage(locale.languageCode);
  }

  bool get isEnglish => state.languageCode == 'en';
  bool get isArabic => state.languageCode == 'ar';
  bool get isFrench => state.languageCode == 'fr';

  String get languageCode => state.languageCode;
  String get countryCode => state.countryCode ?? '';
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
