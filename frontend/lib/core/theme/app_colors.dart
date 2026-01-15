import 'package:flutter/material.dart';
import 'whizz_colors.dart';

/// Application color palette - DEPRECATED
/// 
/// ⚠️ Use WhizzColors instead. This delegates to WhizzColors for backward compatibility.
@Deprecated('Use WhizzColors instead')
class AppColors {
  AppColors._();

  // PRIMARY COLORS
  static Color get primary => WhizzColors.brandYellowAlt;
  static Color get primaryLight => const Color(0xFFFFE666);
  static Color get primaryDark => WhizzColors.brandYellow;
  static Color get primaryContainer => WhizzColors.brandYellowAlt.withValues(alpha: 0.1);
  
  // SECONDARY COLORS
  static Color get secondary => WhizzColors.brandBlueDark;
  static Color get secondaryLight => WhizzColors.brandBluePrimary;
  static Color get secondaryDark => WhizzColors.brandBlueDark;
  static Color get secondaryContainer => WhizzColors.brandBlueDark.withValues(alpha: 0.1);
  
  // SURFACE COLORS
  static Color get surface => WhizzColors.white;
  @Deprecated('Use surfaceContainerHighest')
  static Color get surfaceVariant => WhizzColors.grey100;
  static Color get surfaceContainer => WhizzColors.grey50;
  static Color get surfaceContainerHigh => WhizzColors.grey100;
  static Color get surfaceContainerHighest => WhizzColors.grey200;
  
  // BACKGROUND COLORS
  @Deprecated('Use surface')
  static Color get background => WhizzColors.white;
  static Color get backgroundVariant => WhizzColors.grey50;
  
  // TEXT COLORS
  static Color get onPrimary => WhizzColors.black;
  static Color get onPrimaryContainer => WhizzColors.black;
  static Color get onSecondary => WhizzColors.white;
  static Color get onSecondaryContainer => WhizzColors.brandBlueDark;
  static Color get onSurface => WhizzColors.black;
  static Color get onSurfaceVariant => WhizzColors.textSecondary;
  @Deprecated('Use onSurface')
  static Color get onBackground => WhizzColors.black;
  static Color get textPrimary => WhizzColors.textPrimary;
  static Color get textSecondary => WhizzColors.textSecondary;
  static Color get onError => WhizzColors.white;
  static Color get onErrorContainer => WhizzColors.error;
  
  // STATUS COLORS
  static Color get success => WhizzColors.success;
  static Color get successContainer => WhizzColors.successContainer;
  static Color get warning => WhizzColors.warning;
  static Color get warningContainer => WhizzColors.warningContainer;
  static Color get error => WhizzColors.error;
  static Color get errorContainer => WhizzColors.errorContainer;
  static Color get info => WhizzColors.info;
  static Color get infoContainer => WhizzColors.infoContainer;
  
  // BORDER COLORS
  @Deprecated('Use WhizzColors.borderPrimary')
  static Color get border => WhizzColors.borderPrimary;
  @Deprecated('Use WhizzColors.borderPrimary')
  static Color get borderLight => WhizzColors.borderPrimary;
  @Deprecated('Use WhizzColors.borderPrimary')
  static Color get borderDark => WhizzColors.borderPrimary;
  
  // DIVIDER & SHADOW
  static Color get divider => WhizzColors.grey200;
  static Color get dividerLight => WhizzColors.grey200;
  static Color get shadow => WhizzColors.shadow;
  static Color get shadowMedium => WhizzColors.shadowMedium;
  static Color get shadowDark => WhizzColors.shadowDark;
}
