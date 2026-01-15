import 'package:flutter/material.dart';
import '../core/theme/whizz_colors.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../services/language_service.dart';

class LanguageSwitcher extends StatelessWidget {
  final bool showText;
  final bool isDropdown;
  final bool? showAsIcon;
  final Color? iconColor;
  final Color? textColor;
  
  const LanguageSwitcher({
    super.key,
    this.showText = true,
    this.isDropdown = true,
    this.showAsIcon,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        if (isDropdown) {
          return _buildDropdown(context, localeProvider);
        } else {
          return _buildIconButton(context, localeProvider);
        }
      },
    );
  }

  Widget _buildDropdown(BuildContext context, LocaleProvider localeProvider) {
    return DropdownButton<String>(
      value: localeProvider.languageCode,
      icon: Icon(Icons.language, color: iconColor),
      underline: Container(),
      items: LanguageService.getSupportedLanguageCodes().map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _getLanguageFlag(value),
              if (showText) ...[
                const SizedBox(width: 8),
                Text(
                  LanguageService.getLanguageDisplayName(value),
                  style: TextStyle(color: textColor),
                ),
              ],
            ],
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          _changeLanguage(context, localeProvider, newValue);
        }
      },
    );
  }

  Widget _buildIconButton(BuildContext context, LocaleProvider localeProvider) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.language, color: iconColor),
      onSelected: (String languageCode) {
        _changeLanguage(context, localeProvider, languageCode);
      },
      itemBuilder: (BuildContext context) {
        return LanguageService.getSupportedLanguageCodes().map((String value) {
          return PopupMenuItem<String>(
            value: value,
            child: Row(
              children: [
                _getLanguageFlag(value),
                const SizedBox(width: 8),
                Text(LanguageService.getLanguageDisplayName(value)),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  Widget _getLanguageFlag(String languageCode) {
    String flag;
    switch (languageCode) {
      case 'ar':
        flag = '🇸🇦';
        break;
      case 'fr':
        flag = '🇫🇷';
        break;
      case 'en':
      default:
        flag = '🇺🇸';
        break;
    }
    return Text(flag, style: const TextStyle(fontSize: 20));
  }

  void _changeLanguage(BuildContext context, LocaleProvider localeProvider,
      String languageCode) async {
    final locale = LanguageService.getLocaleFromLanguageCode(languageCode);
    localeProvider.setLocale(locale);
    await LanguageService.saveLanguage(languageCode);
    
    // Show a snackbar to confirm the language change
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Language changed to ${LanguageService.getLanguageDisplayName(languageCode)}',
              style: TextStyle(color: WhizzColors.secondary)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
