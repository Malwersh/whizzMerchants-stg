import 'package:flutter/material.dart';
import '../golden_ratio_constants.dart';
import '../typography_system.dart';
import '../../theme/whizz_colors.dart';

/// Button Themes
///
/// Provides consistent button styling throughout the app using
/// Material Design 3 patterns with golden ratio proportions.

class ButtonThemes {
  ButtonThemes._();

  // ══════════════════════════════════════════════════════════════════════════
  // ELEVATED BUTTON STYLES
  // ══════════════════════════════════════════════════════════════════════════

  static final ButtonStyle primaryElevatedButton = ElevatedButton.styleFrom(
    backgroundColor: WhizzColors.primary,
    foregroundColor: Colors.white,
    elevation: GoldenRatio.xs,
    padding: const EdgeInsets.symmetric(
      horizontal: GoldenRatio.lg,
      vertical: GoldenRatio.md,
    ),
    minimumSize: const Size(GoldenRatio.xl * 2, GoldenRatio.xl),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GoldenRatio.md),
    ),
    textStyle: TypographySystem.labelLarge,
  );

  static final ButtonStyle secondaryElevatedButton = ElevatedButton.styleFrom(
    backgroundColor: WhizzColors.secondary,
    foregroundColor: Colors.black,
    elevation: GoldenRatio.xs,
    padding: const EdgeInsets.symmetric(
      horizontal: GoldenRatio.lg,
      vertical: GoldenRatio.md,
    ),
    minimumSize: const Size(GoldenRatio.xl * 2, GoldenRatio.xl),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GoldenRatio.md),
    ),
    textStyle: TypographySystem.labelLarge,
  );

  static final ButtonStyle largeElevatedButton = ElevatedButton.styleFrom(
    backgroundColor: WhizzColors.primary,
    foregroundColor: Colors.white,
    elevation: GoldenRatio.sm,
    padding: const EdgeInsets.symmetric(
      horizontal: GoldenRatio.xl,
      vertical: GoldenRatio.lg,
    ),
    minimumSize: const Size(GoldenRatio.xl * 3, GoldenRatio.xl * 1.5),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GoldenRatio.lg),
    ),
    textStyle: TypographySystem.titleMedium,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // OUTLINED BUTTON STYLES
  // ══════════════════════════════════════════════════════════════════════════

  static final ButtonStyle primaryOutlinedButton = OutlinedButton.styleFrom(
    foregroundColor: WhizzColors.primary,
    padding: const EdgeInsets.symmetric(
      horizontal: GoldenRatio.lg,
      vertical: GoldenRatio.md,
    ),
    minimumSize: const Size(GoldenRatio.xl * 2, GoldenRatio.xl),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GoldenRatio.md),
    ),
    side: BorderSide(
      color: WhizzColors.primary,
      width: 1.5,
    ),
    textStyle: TypographySystem.labelLarge,
  );

  static final ButtonStyle secondaryOutlinedButton = OutlinedButton.styleFrom(
    foregroundColor: WhizzColors.secondary,
    padding: const EdgeInsets.symmetric(
      horizontal: GoldenRatio.lg,
      vertical: GoldenRatio.md,
    ),
    minimumSize: const Size(GoldenRatio.xl * 2, GoldenRatio.xl),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GoldenRatio.md),
    ),
    side: BorderSide(
      color: WhizzColors.secondary,
      width: 1.5,
    ),
    textStyle: TypographySystem.labelLarge,
  );

  static final ButtonStyle largeOutlinedButton = OutlinedButton.styleFrom(
    foregroundColor: WhizzColors.primary,
    padding: EdgeInsets.symmetric(
      horizontal: GoldenRatio.xl,
      vertical: GoldenRatio.lg,
    ),
    minimumSize: Size(GoldenRatio.xl * 3, GoldenRatio.xl * 1.5),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GoldenRatio.lg),
    ),
    side: BorderSide(
      color: WhizzColors.primary,
      width: 2,
    ),
    textStyle: TypographySystem.titleMedium,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // TEXT BUTTON STYLES
  // ══════════════════════════════════════════════════════════════════════════

  static final ButtonStyle primaryTextButton = TextButton.styleFrom(
    foregroundColor: WhizzColors.primary,
    padding: EdgeInsets.symmetric(
      horizontal: GoldenRatio.md,
      vertical: GoldenRatio.sm,
    ),
    minimumSize: Size(GoldenRatio.lg, GoldenRatio.lg),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GoldenRatio.sm),
    ),
    textStyle: TypographySystem.labelLarge,
  );

  static final ButtonStyle secondaryTextButton = TextButton.styleFrom(
    foregroundColor: WhizzColors.secondary,
    padding: EdgeInsets.symmetric(
      horizontal: GoldenRatio.md,
      vertical: GoldenRatio.sm,
    ),
    minimumSize: Size(GoldenRatio.lg, GoldenRatio.lg),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GoldenRatio.sm),
    ),
    textStyle: TypographySystem.labelLarge,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // FLOATING ACTION BUTTON STYLES
  // ══════════════════════════════════════════════════════════════════════════

  static final FloatingActionButtonThemeData fabTheme =
      FloatingActionButtonThemeData(
    backgroundColor: WhizzColors.primary,
    foregroundColor: Colors.white,
    elevation: GoldenRatio.sm,
    focusElevation: GoldenRatio.md,
    hoverElevation: GoldenRatio.md,
    highlightElevation: GoldenRatio.lg,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GoldenRatio.lg),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // ICON BUTTON STYLES
  // ══════════════════════════════════════════════════════════════════════════

  static final ButtonStyle primaryIconButton = IconButton.styleFrom(
    foregroundColor: WhizzColors.primary,
    backgroundColor: WhizzColors.primary.withValues(alpha: 0.12),
    padding: EdgeInsets.all(GoldenRatio.sm),
    minimumSize: Size(GoldenRatio.xl, GoldenRatio.xl),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GoldenRatio.sm),
    ),
  );

  static final ButtonStyle secondaryIconButton = IconButton.styleFrom(
    foregroundColor: WhizzColors.secondary,
    backgroundColor: WhizzColors.secondary.withValues(alpha: 0.12),
    padding: EdgeInsets.all(GoldenRatio.sm),
    minimumSize: Size(GoldenRatio.xl, GoldenRatio.xl),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GoldenRatio.sm),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // SPECIALIZED BUTTON STYLES
  // ══════════════════════════════════════════════════════════════════════════

  /// Success button style (green background)
  static final ButtonStyle successButton = ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF2E7D32), // Material green
    foregroundColor: Colors.white,
    elevation: GoldenRatio.xs,
    padding: EdgeInsets.symmetric(
      horizontal: GoldenRatio.lg,
      vertical: GoldenRatio.md,
    ),
    minimumSize: Size(GoldenRatio.xl * 2, GoldenRatio.xl),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GoldenRatio.md),
    ),
    textStyle: TypographySystem.labelLarge,
  );

  /// Destructive button style (red background)
  static final ButtonStyle destructiveButton = ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFBA1A1A), // Material red
    foregroundColor: Colors.white,
    elevation: GoldenRatio.xs,
    padding: EdgeInsets.symmetric(
      horizontal: GoldenRatio.lg,
      vertical: GoldenRatio.md,
    ),
    minimumSize: Size(GoldenRatio.xl * 2, GoldenRatio.xl),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GoldenRatio.md),
    ),
    textStyle: TypographySystem.labelLarge,
  );

  /// Disabled button style
  static final ButtonStyle disabledButton = ElevatedButton.styleFrom(
    backgroundColor: Colors.grey.withValues(alpha: 0.3),
    foregroundColor: Colors.grey.withValues(alpha: 0.5),
    elevation: 0,
    padding: EdgeInsets.symmetric(
      horizontal: GoldenRatio.lg,
      vertical: GoldenRatio.md,
    ),
    minimumSize: Size(GoldenRatio.xl * 2, GoldenRatio.xl),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GoldenRatio.md),
    ),
    textStyle: TypographySystem.labelLarge,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ══════════════════════════════════════════════════════════════════════════

  /// Creates a custom button style with specified colors
  static ButtonStyle customElevatedButton({
    required Color backgroundColor,
    required Color foregroundColor,
    double? elevation,
    EdgeInsets? padding,
    BorderRadius? borderRadius,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation ?? GoldenRatio.xs,
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: GoldenRatio.lg,
            vertical: GoldenRatio.md,
          ),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(GoldenRatio.md),
      ),
      textStyle: TypographySystem.labelLarge,
    );
  }

  /// Creates a custom outlined button style with specified colors
  static ButtonStyle customOutlinedButton({
    required Color foregroundColor,
    required Color borderColor,
    EdgeInsets? padding,
    BorderRadius? borderRadius,
    double borderWidth = 1.5,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: foregroundColor,
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: GoldenRatio.lg,
            vertical: GoldenRatio.md,
          ),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(GoldenRatio.md),
      ),
      side: BorderSide(
        color: borderColor,
        width: borderWidth,
      ),
      textStyle: TypographySystem.labelLarge,
    );
  }
}
