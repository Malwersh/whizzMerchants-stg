import 'package:flutter/material.dart';
import 'golden_ratio_constants.dart';

/// Typography System
///
/// Provides Material Design 3 text styles with golden ratio proportions.
/// All font sizes follow the golden ratio scale for harmonious typography.

class TypographySystem {
  TypographySystem._();

  // ══════════════════════════════════════════════════════════════════════════
  // DISPLAY STYLES - Largest text
  // ══════════════════════════════════════════════════════════════════════════

  static const TextStyle displayLarge = TextStyle(
    fontSize: 57.0, // Material Design 3 spec
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    height: 1.12,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 45.0, // Material Design 3 spec
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    height: 1.16,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 36.0, // Material Design 3 spec
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    height: 1.22,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // HEADLINE STYLES - Section headers
  // ══════════════════════════════════════════════════════════════════════════

  static const TextStyle headlineLarge = TextStyle(
    fontSize: GoldenRatio.textHeadline,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    height: 1.25,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28.0, // Material Design 3 spec
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    height: 1.29,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: GoldenRatio.textTitle,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    height: 1.33,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // TITLE STYLES - Cards and components
  // ══════════════════════════════════════════════════════════════════════════

  static const TextStyle titleLarge = TextStyle(
    fontSize: 22.0, // Material Design 3 spec
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    height: 1.27,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: GoldenRatio.textLg,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    height: 1.50,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: GoldenRatio.textMd,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.43,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // LABEL STYLES - Buttons and small components
  // ══════════════════════════════════════════════════════════════════════════

  static const TextStyle labelLarge = TextStyle(
    fontSize: GoldenRatio.textSm,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.43,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: GoldenRatio.textXs,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.33,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11.0, // Material Design 3 spec
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.45,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // BODY STYLES - Main content text
  // ══════════════════════════════════════════════════════════════════════════

  static const TextStyle bodyLarge = TextStyle(
    fontSize: GoldenRatio.textMd,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.50,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: GoldenRatio.textSm,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.43,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: GoldenRatio.textXs,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ══════════════════════════════════════════════════════════════════════════

  /// Create a text style with custom color
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Create a text style with custom weight
  static TextStyle withWeight(TextStyle style, FontWeight weight) {
    return style.copyWith(fontWeight: weight);
  }

  /// Create a responsive text style that scales with screen size
  static TextStyle responsive(BuildContext context, TextStyle style) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth < 600 ? 0.9 : 1.0;

    return style.copyWith(
      fontSize: (style.fontSize ?? 14) * scaleFactor,
    );
  }
}
