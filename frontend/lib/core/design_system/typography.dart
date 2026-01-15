import 'package:flutter/material.dart';

/// Design System - Typography Scale
///
/// Material Design 3 typography scale with responsive support.
/// Provides consistent text styling across the application.
class AppTypography {
  AppTypography._(); // Private constructor

  /// Default font family for the app
  static const String defaultFontFamily = 'Roboto';

  // ============================================================================
  // DISPLAY STYLES (Hero text, large headlines)
  // ============================================================================

  /// Display Large - 57sp
  /// Use for: Hero text, splash screens
  static const TextStyle displayLarge = TextStyle(
    fontSize: 57.0,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    height: 64.0 / 57.0, // Line height / font size
  );

  /// Display Medium - 45sp
  /// Use for: Large headings, feature titles
  static const TextStyle displayMedium = TextStyle(
    fontSize: 45.0,
    fontWeight: FontWeight.w400,
    height: 52.0 / 45.0,
  );

  /// Display Small - 36sp
  /// Use for: Medium large headings
  static const TextStyle displaySmall = TextStyle(
    fontSize: 36.0,
    fontWeight: FontWeight.w400,
    height: 44.0 / 36.0,
  );

  // ============================================================================
  // HEADLINE STYLES (Section titles, page headers)
  // ============================================================================

  /// Headline Large - 32sp
  /// Use for: Main page titles, major sections
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32.0,
    fontWeight: FontWeight.w600,
    height: 40.0 / 32.0,
  );

  /// Headline Medium - 28sp
  /// Use for: Section headers, card titles
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.w600,
    height: 36.0 / 28.0,
  );

  /// Headline Small - 24sp
  /// Use for: Subsection headers
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w600,
    height: 32.0 / 24.0,
  );

  // ============================================================================
  // TITLE STYLES (Card titles, list headers)
  // ============================================================================

  /// Title Large - 22sp
  /// Use for: Prominent titles, dialog headers
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.w600,
    height: 28.0 / 22.0,
  );

  /// Title Medium - 16sp
  /// Use for: Medium emphasis titles, list headers
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 24.0 / 16.0,
  );

  /// Title Small - 14sp
  /// Use for: Small titles, dense lists
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 20.0 / 14.0,
  );

  // ============================================================================
  // BODY STYLES (Main content, paragraphs)
  // ============================================================================

  /// Body Large - 16sp
  /// Use for: Main content, readable paragraphs
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 24.0 / 16.0,
  );

  /// Body Medium - 14sp (Most common)
  /// Use for: Body text, descriptions, most UI text
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 20.0 / 14.0,
  );

  /// Body Small - 12sp
  /// Use for: Captions, helper text, small descriptions
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 16.0 / 12.0,
  );

  // ============================================================================
  // LABEL STYLES (Buttons, chips, form labels)
  // ============================================================================

  /// Label Large - 14sp
  /// Use for: Prominent buttons, emphasized labels
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 20.0 / 14.0,
  );

  /// Label Medium - 12sp
  /// Use for: Standard buttons, chips, form labels
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 16.0 / 12.0,
  );

  /// Label Small - 11sp
  /// Use for: Small labels, overline text
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 16.0 / 11.0,
  );

  // ============================================================================
  // UTILITY STYLES
  // ============================================================================

  /// Overline - 10sp, uppercase
  /// Use for: Overline text, eyebrow text
  static const TextStyle overline = TextStyle(
    fontSize: 10.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    height: 16.0 / 10.0,
  );

  /// Caption - 12sp
  /// Use for: Timestamps, metadata, fine print
  static const TextStyle caption = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 16.0 / 12.0,
  );

  // ============================================================================
  // BUTTON TEXT STYLES
  // ============================================================================

  /// Large button text - 16sp
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  /// Medium button text - 14sp (Standard)
  static const TextStyle buttonMedium = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  /// Small button text - 12sp
  static const TextStyle buttonSmall = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  // ============================================================================
  // NUMBER & STAT STYLES
  // ============================================================================

  /// Large number display - 48sp
  /// Use for: Hero numbers, large statistics
  static const TextStyle numberLarge = TextStyle(
    fontSize: 48.0,
    fontWeight: FontWeight.w700,
    height: 56.0 / 48.0,
  );

  /// Medium number display - 32sp
  /// Use for: Cards with numbers, medium stats
  static const TextStyle numberMedium = TextStyle(
    fontSize: 32.0,
    fontWeight: FontWeight.w700,
    height: 40.0 / 32.0,
  );

  /// Small number display - 24sp
  /// Use for: Inline numbers, small stats
  static const TextStyle numberSmall = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w700,
    height: 32.0 / 24.0,
  );

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Apply color to a text style
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Apply font weight to a text style
  static TextStyle withWeight(TextStyle style, FontWeight weight) {
    return style.copyWith(fontWeight: weight);
  }

  /// Apply font size to a text style
  static TextStyle withSize(TextStyle style, double size) {
    return style.copyWith(fontSize: size);
  }

  /// Apply letter spacing to a text style
  static TextStyle withLetterSpacing(TextStyle style, double spacing) {
    return style.copyWith(letterSpacing: spacing);
  }

  /// Apply height (line height multiplier) to a text style
  static TextStyle withHeight(TextStyle style, double height) {
    return style.copyWith(height: height);
  }

  /// Make text style bold
  static TextStyle bold(TextStyle style) {
    return style.copyWith(fontWeight: FontWeight.w700);
  }

  /// Make text style semi-bold
  static TextStyle semiBold(TextStyle style) {
    return style.copyWith(fontWeight: FontWeight.w600);
  }

  /// Make text style medium
  static TextStyle medium(TextStyle style) {
    return style.copyWith(fontWeight: FontWeight.w500);
  }

  /// Make text style regular
  static TextStyle regular(TextStyle style) {
    return style.copyWith(fontWeight: FontWeight.w400);
  }

  /// Make text style italic
  static TextStyle italic(TextStyle style) {
    return style.copyWith(fontStyle: FontStyle.italic);
  }

  /// Make text style underlined
  static TextStyle underlined(TextStyle style) {
    return style.copyWith(decoration: TextDecoration.underline);
  }

  /// Make text style strikethrough
  static TextStyle strikethrough(TextStyle style) {
    return style.copyWith(decoration: TextDecoration.lineThrough);
  }

  // ============================================================================
  // RESPONSIVE TYPOGRAPHY
  // ============================================================================

  /// Get responsive display style based on screen width
  static TextStyle getResponsiveDisplay(double screenWidth) {
    if (screenWidth < 600) return displaySmall;
    if (screenWidth < 1024) return displayMedium;
    return displayLarge;
  }

  /// Get responsive headline style based on screen width
  static TextStyle getResponsiveHeadline(double screenWidth) {
    if (screenWidth < 600) return headlineSmall;
    if (screenWidth < 1024) return headlineMedium;
    return headlineLarge;
  }

  /// Get responsive body style based on screen width
  static TextStyle getResponsiveBody(double screenWidth) {
    if (screenWidth < 600) return bodyMedium;
    return bodyLarge;
  }
}
