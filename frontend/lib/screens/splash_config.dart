/*
 * Whizz Merchant Splash Screen - Configuration Constants
 * 
 * This file contains all customizable constants for the splash screen.
 * Modify these values to customize the splash screen appearance and behavior.
 */

import 'package:flutter/material.dart';
import '../core/theme/whizz_colors.dart';

class SplashConfig {
  SplashConfig._();

  // ============================================================================
  // DURATION & TIMING
  // ============================================================================

  /// Total duration the splash screen is visible
  static const Duration displayDuration = Duration(seconds: 3);

  /// Duration of entrance animations
  static const Duration entranceAnimationDuration =
      Duration(milliseconds: 1500);

  /// Duration of pulse animation cycle
  static const Duration pulseAnimationDuration = Duration(milliseconds: 1200);

  /// Duration of background rotation cycle
  static const Duration rotationAnimationDuration = Duration(seconds: 20);

  // ============================================================================
  // COLORS
  // ============================================================================

  /// Background color
  static const Color backgroundColor = WhizzColors.white;

  /// Logo gradient colors
  static const List<Color> logoGradientColors = [
    WhizzColors.primary,
    WhizzColors.primary,
  ];

  /// Logo text color
  static const Color logoTextColor = WhizzColors.black;

  /// App name color
  static const Color appNameColor = WhizzColors.black;

  /// Badge background color
  static const Color badgeBackgroundColor = WhizzColors.primary;

  /// Badge text color
  static const Color badgeTextColor = WhizzColors.black;

  /// Tagline color
  static const Color taglineColor = WhizzColors.grey600;

  /// Loading indicator color
  static const Color loadingIndicatorColor = WhizzColors.primary;

  /// Footer text color
  static const Color footerTextColor = WhizzColors.grey500;

  /// Glow color (for pulse effect)
  static const Color glowColor = WhizzColors.primary;

  // ============================================================================
  // SIZES
  // ============================================================================

  /// Logo circle diameter
  static const double logoSize = 140.0;

  /// Logo text size
  static const double logoTextSize = 72.0;

  /// Loading indicator size
  static const double loadingIndicatorSize = 40.0;

  /// Loading indicator stroke width
  static const double loadingIndicatorStrokeWidth = 3.0;

  // ============================================================================
  // TEXT CONTENT
  // ============================================================================

  /// Logo letter/text
  static const String logoText = 'W';

  /// Main app name
  static const String appName = 'WHIZZ';

  /// Badge text (subtitle)
  static const String badgeText = 'MERCHANTS';

  /// Tagline
  static const String tagline = 'Manage Your Business, Effortlessly';

  /// Footer primary text
  static const String footerPrimaryText = 'Powered by Whizz Ecosystem';

  /// Footer version text
  static const String footerVersionText = 'Version 1.0.0';

  /// App name letter spacing
  static const double appNameLetterSpacing = 4.0;

  /// Badge letter spacing
  static const double badgeLetterSpacing = 3.0;

  /// Tagline letter spacing
  static const double taglineLetterSpacing = 0.5;

  // ============================================================================
  // ANIMATION PARAMETERS
  // ============================================================================

  /// Fade animation range
  static const double fadeAnimationStart = 0.0;
  static const double fadeAnimationEnd = 1.0;

  /// Scale animation range
  static const double scaleAnimationStart = 0.5;
  static const double scaleAnimationEnd = 1.0;

  /// Slide animation range (in pixels)
  static const double slideAnimationStart = 50.0;
  static const double slideAnimationEnd = 0.0;

  /// Pulse animation range
  static const double pulseAnimationStart = 1.0;
  static const double pulseAnimationEnd = 1.3;

  /// Glow blur radius (max)
  static const double glowBlurRadius = 40.0;

  /// Glow spread radius (max)
  static const double glowSpreadRadius = 10.0;

  /// Glow opacity (base)
  static const double glowOpacity = 0.4;

  // ============================================================================
  // BACKGROUND DECORATIONS
  // ============================================================================

  /// Top-right circle size ratio (relative to screen width)
  static const double topRightCircleSizeRatio = 0.6;

  /// Bottom-left circle size ratio (relative to screen width)
  static const double bottomLeftCircleSizeRatio = 0.5;

  /// Top-right circle opacity
  static const double topRightCircleOpacity = 0.15;

  /// Bottom-left circle opacity
  static const double bottomLeftCircleOpacity = 0.2;

  /// Number of floating accent squares
  static const int floatingSquaresCount = 3;

  /// Floating square size
  static const double floatingSquareSize = 30.0;

  /// Floating square border radius
  static const double floatingSquareBorderRadius = 6.0;

  /// Floating square border width
  static const double floatingSquareBorderWidth = 2.0;

  /// Floating square fill opacity
  static const double floatingSquareFillOpacity = 0.1;

  /// Floating square border opacity
  static const double floatingSquareBorderOpacity = 0.3;

  /// Floating squares orbit radius ratio (relative to screen width)
  static const double floatingSquaresOrbitRatio = 0.35;

  // ============================================================================
  // TRANSITION SETTINGS
  // ============================================================================

  /// Navigation transition duration
  static const Duration navigationTransitionDuration =
      Duration(milliseconds: 500);

  /// Use fade transition for navigation
  static const bool useFadeTransition = true;

  // ============================================================================
  // BADGE SETTINGS
  // ============================================================================

  /// Badge horizontal padding
  static const double badgeHorizontalPadding = 24.0;

  /// Badge vertical padding
  static const double badgeVerticalPadding = 8.0;

  /// Badge border radius
  static const double badgeBorderRadius = 20.0;

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get logo gradient
  static LinearGradient getLogoGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: logoGradientColors,
    );
  }

  /// Get glow shadow with animated scale
  static List<BoxShadow> getGlowShadow(double pulseValue) {
    return [
      BoxShadow(
        color: glowColor.withValues(alpha: glowOpacity * pulseValue),
        blurRadius: glowBlurRadius * pulseValue,
        spreadRadius: glowSpreadRadius * (pulseValue - 1),
      ),
    ];
  }

  /// Get background circle gradient
  static RadialGradient getBackgroundGradient(Color color, double opacity) {
    return RadialGradient(
      colors: [
        color.withValues(alpha: opacity),
        color.withValues(alpha: opacity * 0.5),
        Colors.transparent,
      ],
    );
  }
}
