import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/language_provider_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../core/design_system/design_system.dart';

class LanguageSettingsBottomDrawer extends ConsumerStatefulWidget {
  const LanguageSettingsBottomDrawer({super.key});

  @override
  ConsumerState<LanguageSettingsBottomDrawer> createState() =>
      _LanguageSettingsBottomDrawerState();

  /// Static method to show the bottom drawer
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LanguageSettingsBottomDrawer(),
    );
  }
}

class _LanguageSettingsBottomDrawerState
    extends ConsumerState<LanguageSettingsBottomDrawer> {
  Future<void> _changeLanguage(Locale locale) async {
    final languageNotifier = ref.read(languageProviderRiverpod.notifier);
    await languageNotifier.setLanguage(locale);

    if (mounted) {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: WhizzColors.white),
              SizedBox(width: AppSpacing.sm),
              Text(
                loc.languageChangedSuccessfully,
                style: AppTypography.bodyMedium.copyWith(
                  color: WhizzColors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor: WhizzColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(languageProviderRiverpod);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: WhizzColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppDimensions.borderRadiusXL),
          topRight: Radius.circular(AppDimensions.borderRadiusXL),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: WhizzColors.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.lg),

              // Title
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.borderRadiusSM),
                    ),
                    child: Icon(
                      Icons.language_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Text(
                    loc.languageSettings,
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: WhizzColors.black,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.xs),
              Padding(
                padding: EdgeInsets.only(left: AppSpacing.xl + AppSpacing.md),
                child: Text(
                  loc.selectYourPreferredLanguage,
                  style: AppTypography.bodyMedium.copyWith(
                    color: WhizzColors.grey600,
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.xl),

              // Language options
              _buildLanguageOption(
                context: context,
                locale: const Locale('en', ''),
                title: 'English',
                subtitle: 'English',
                isSelected: currentLocale.languageCode == 'en',
                icon: '🇬🇧',
              ),
              SizedBox(height: AppSpacing.md),
              _buildLanguageOption(
                context: context,
                locale: const Locale('ar', ''),
                title: 'العربية',
                subtitle: 'Arabic',
                isSelected: currentLocale.languageCode == 'ar',
                icon: '🇸🇦',
              ),
              SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required Locale locale,
    required String title,
    required String subtitle,
    required bool isSelected,
    required String icon,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : WhizzColors.grey50,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
        border: Border.all(
          color: isSelected ? theme.colorScheme.primary : WhizzColors.grey200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _changeLanguage(locale),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // Flag icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: WhizzColors.white,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadiusSM),
                    border: Border.all(
                      color: WhizzColors.grey200,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      icon,
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),

                // Language name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: WhizzColors.black,
                        ),
                      ),
                      SizedBox(height: GoldenRatio.xs),
                      Text(
                        subtitle,
                        style: AppTypography.bodyMedium.copyWith(
                          color: WhizzColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Selection indicator
                if (isSelected)
                  Container(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: const Color(0xFF00296B),
                      size: 16,
                    ),
                  )
                else
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: WhizzColors.grey300,
                        width: 2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
