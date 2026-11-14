import 'package:flutter/material.dart';
import '../theme/whizz_colors.dart';
import '../theme/glass_theme.dart';
import 'golden_ratio_constants.dart';
import 'typography_system.dart';

/// Material Theme Configuration
///
/// Provides complete Material Design 3 themes with golden ratio proportions
/// and the app's brand colors (lime green and gold).

class MaterialTheme {
  MaterialTheme._();

  // ══════════════════════════════════════════════════════════════════════════
  // COLOR SCHEMES
  // ══════════════════════════════════════════════════════════════════════════

  static ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: WhizzColors.primary,
    onPrimary: WhizzColors.secondary,
    primaryContainer: const Color(0xFFFFF8E6),
    onPrimaryContainer: WhizzColors.secondary,
    secondaryContainer: const Color(0xFFEDF2FA),
    onSecondaryContainer: WhizzColors.secondary,
    secondary: WhizzColors.secondary,
    onSecondary: WhizzColors.white,
    error: WhizzColors.error,
    onError: WhizzColors.white,
    surface: WhizzColors.white,
    surfaceContainerLowest: WhizzColors.white,
    surfaceContainerLow: WhizzColors.white,
    surfaceContainer: WhizzColors.white,
    surfaceContainerHigh: WhizzColors.white,
    surfaceContainerHighest: WhizzColors.white,
    onSurface: WhizzColors.black,
    onSurfaceVariant: WhizzColors.grey700,
    outline: WhizzColors.grey600,
    outlineVariant: WhizzColors.grey400,
    shadow: WhizzColors.black,
    scrim: WhizzColors.black,
    inverseSurface: WhizzColors.grey800,
    onInverseSurface: WhizzColors.grey100,
    inversePrimary: WhizzColors.primaryLight,
  );

  static ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: WhizzColors.primaryLight,
    onPrimary: WhizzColors.black,
    secondary: WhizzColors.secondaryLight,
    onSecondary: WhizzColors.black,
    error: WhizzColors.error,
    onError: WhizzColors.white,
    surface: WhizzColors.black,
    onSurface: WhizzColors.white,
    surfaceContainerHighest: WhizzColors.grey700,
    onSurfaceVariant: WhizzColors.grey300,
    outline: WhizzColors.grey500,
    outlineVariant: WhizzColors.grey700,
    shadow: WhizzColors.black,
    scrim: WhizzColors.black,
    inverseSurface: WhizzColors.grey200,
    onInverseSurface: WhizzColors.grey800,
    inversePrimary: WhizzColors.primary,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // TEXT THEMES
  // ══════════════════════════════════════════════════════════════════════════

  static const TextTheme textTheme = TextTheme(
    displayLarge: TypographySystem.displayLarge,
    displayMedium: TypographySystem.displayMedium,
    displaySmall: TypographySystem.displaySmall,
    headlineLarge: TypographySystem.headlineLarge,
    headlineMedium: TypographySystem.headlineMedium,
    headlineSmall: TypographySystem.headlineSmall,
    titleLarge: TypographySystem.titleLarge,
    titleMedium: TypographySystem.titleMedium,
    titleSmall: TypographySystem.titleSmall,
    labelLarge: TypographySystem.labelLarge,
    labelMedium: TypographySystem.labelMedium,
    labelSmall: TypographySystem.labelSmall,
    bodyLarge: TypographySystem.bodyLarge,
    bodyMedium: TypographySystem.bodyMedium,
    bodySmall: TypographySystem.bodySmall,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ══════════════════════════════════════════════════════════════════════════

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: lightColorScheme,
      textTheme: textTheme,
      extensions: [
        GlassThemeData.light(),
      ],

      // Scaffold Theme - Ensure pure white background
      scaffoldBackgroundColor: WhizzColors.white,

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: lightColorScheme.surface,
        foregroundColor: lightColorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TypographySystem.titleLarge.copyWith(
          color: lightColorScheme.onSurface,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: WhizzColors.white, // Explicit pure white background
        surfaceTintColor: Colors.transparent, // No Material 3 tinting
        elevation: GoldenRatio.xs,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.md),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // Readable pairs for default, tonal, and selected controls.
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              backgroundColor: WhizzColors.primary,
              foregroundColor: WhizzColors.secondary)),
      segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? Colors.white
                : WhizzColors.secondary),
        backgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? WhizzColors.secondary
                : Colors.white),
      )),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: WhizzColors.secondary),
      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WhizzColors.primary,
          foregroundColor: WhizzColors.secondary,
          elevation: GoldenRatio.xs,
          padding: EdgeInsets.symmetric(
            horizontal: GoldenRatio.lg,
            vertical: GoldenRatio.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.md),
          ),
          textStyle: TypographySystem.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WhizzColors.secondary,
          padding: EdgeInsets.symmetric(
            horizontal: GoldenRatio.lg,
            vertical: GoldenRatio.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.md),
          ),
          textStyle: TypographySystem.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: WhizzColors.secondary,
          padding: EdgeInsets.symmetric(
            horizontal: GoldenRatio.md,
            vertical: GoldenRatio.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.sm),
          ),
          textStyle: TypographySystem.labelLarge,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            lightColorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: EdgeInsets.symmetric(
          horizontal: GoldenRatio.md,
          vertical: GoldenRatio.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.md),
          borderSide: BorderSide(
            color: lightColorScheme.outline,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.md),
          borderSide: BorderSide(
            color: lightColorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.md),
          borderSide: BorderSide(
            color: lightColorScheme.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.md),
          borderSide: BorderSide(
            color: lightColorScheme.error,
            width: 2,
          ),
        ),
        labelStyle: TypographySystem.bodyMedium,
        hintStyle: TypographySystem.bodyMedium.copyWith(
          color: lightColorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DARK THEME
  // ══════════════════════════════════════════════════════════════════════════

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: darkColorScheme,
      textTheme: textTheme,
      extensions: [
        GlassThemeData.dark(),
      ],

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: darkColorScheme.surface,
        foregroundColor: darkColorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TypographySystem.titleLarge.copyWith(
          color: darkColorScheme.onSurface,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: WhizzColors.grey900, // Dark theme appropriate background
        surfaceTintColor: Colors.transparent, // No Material 3 tinting
        elevation: GoldenRatio.xs,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.md),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: GoldenRatio.xs,
          padding: EdgeInsets.symmetric(
            horizontal: GoldenRatio.lg,
            vertical: GoldenRatio.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.md),
          ),
          textStyle: TypographySystem.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: GoldenRatio.lg,
            vertical: GoldenRatio.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.md),
          ),
          textStyle: TypographySystem.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: GoldenRatio.md,
            vertical: GoldenRatio.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.sm),
          ),
          textStyle: TypographySystem.labelLarge,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            darkColorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: EdgeInsets.symmetric(
          horizontal: GoldenRatio.md,
          vertical: GoldenRatio.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.md),
          borderSide: BorderSide(
            color: darkColorScheme.outline,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.md),
          borderSide: BorderSide(
            color: darkColorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.md),
          borderSide: BorderSide(
            color: darkColorScheme.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.md),
          borderSide: BorderSide(
            color: darkColorScheme.error,
            width: 2,
          ),
        ),
        labelStyle: TypographySystem.bodyMedium,
        hintStyle: TypographySystem.bodyMedium.copyWith(
          color: darkColorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
