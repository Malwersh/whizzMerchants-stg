/// Design System
///
/// Main export file for the comprehensive design system that provides
/// unified access to all design components, themes, and utilities.
///
/// This design system follows Material Design 3 principles with
/// golden ratio proportions and the app's brand colors (lime green and gold).
library;

import 'package:flutter/material.dart';

// MARK: - Core Design System Exports
export 'golden_ratio_constants.dart';
export 'spacing_system.dart';
export 'typography_system.dart';
export 'material_theme.dart';

// MARK: - New Material Design 3 Compliant Components
export 'spacing.dart'; // AppSpacing - 8pt grid system
export 'dimensions.dart'; // AppDimensions - Component dimensions
export 'typography.dart'; // AppTypography - Material 3 type scale
export 'animations.dart'; // AppAnimations - Motion design

// MARK: - Theme Components
export 'themes/button_themes.dart';
export 'themes/card_themes.dart';
export 'themes/navigation_themes.dart';

// MARK: - Colors (Centralized)
// WhizzColors is the single source of truth for all colors
export '../theme/whizz_colors.dart';
// WhizzColors is kept for backward compatibility but delegates to WhizzColors
export '../theme/app_colors.dart';
export '../theme/glass_theme.dart';

// MARK: - Import dependencies for the main class
import 'golden_ratio_constants.dart';
import 'typography_system.dart';
import 'material_theme.dart';
import 'themes/button_themes.dart';
import '../theme/whizz_colors.dart';

/// Design System class providing unified access to all design components
class DesignSystem {
  DesignSystem._();

  // MARK: - Theme Configurations
  /// Get light theme with design system integration
  static ThemeData get lightTheme => MaterialTheme.lightTheme;

  /// Get dark theme with design system integration
  static ThemeData get darkTheme => MaterialTheme.darkTheme;

  // MARK: - Design Tokens
  /// Primary brand color (lime green)
  static Color get primaryColor => WhizzColors.primary;

  /// Secondary brand color (gold)
  static Color get secondaryColor => WhizzColors.secondary;

  /// Error color
  static const Color errorColor = Color(0xFFBA1A1A);

  /// Success color
  static const Color successColor = Color(0xFF2E7D32);

  /// Warning color
  static const Color warningColor = Color(0xFFED6C02);

  /// Info color
  static const Color infoColor = Color(0xFF0288D1);

  // MARK: - Common Measurements
  /// Standard border radius
  static double get borderRadius => GoldenRatio.md;

  /// Standard elevation
  static double get elevation => GoldenRatio.xs;

  /// Standard icon size
  static double get iconSize => GoldenRatio.lg;

  /// Standard button height
  static double get buttonHeight => GoldenRatio.xl;

  /// Standard padding
  static EdgeInsets get padding => const EdgeInsets.all(GoldenRatio.md);

  // MARK: - Utility Methods
  /// Create a consistent card with standard styling
  static Widget card({
    required Widget child,
    EdgeInsets? padding,
    VoidCallback? onTap,
    double? elevation,
  }) {
    return Card(
      elevation: elevation ?? GoldenRatio.xs,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GoldenRatio.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GoldenRatio.md),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(GoldenRatio.md),
          child: child,
        ),
      ),
    );
  }

  /// Create a consistent button with primary styling
  static Widget primaryButton({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    bool isLarge = false,
  }) {
    final style = isLarge
        ? ButtonThemes.largeElevatedButton
        : ButtonThemes.primaryElevatedButton;

    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: GoldenRatio.md,
                height: GoldenRatio.md,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(text),
        style: style,
      );
    } else {
      return ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: style,
        child: isLoading
            ? const SizedBox(
                width: GoldenRatio.md,
                height: GoldenRatio.md,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(text),
      );
    }
  }

  /// Create a consistent secondary button
  static Widget secondaryButton({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    bool isLarge = false,
  }) {
    final style = isLarge
        ? ButtonThemes.largeOutlinedButton
        : ButtonThemes.primaryOutlinedButton;

    if (icon != null) {
      return OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: GoldenRatio.md,
                height: GoldenRatio.md,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(text),
        style: style,
      );
    } else {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: style,
        child: isLoading
            ? const SizedBox(
                width: GoldenRatio.md,
                height: GoldenRatio.md,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(text),
      );
    }
  }

  /// Create a consistent text field
  static Widget textField({
    String? label,
    String? hint,
    String? initialValue,
    ValueChanged<String>? onChanged,
    TextEditingController? controller,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    Widget? prefixIcon,
    int? maxLines = 1,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      onChanged: onChanged,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      enabled: enabled,
      style: TypographySystem.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
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
            color: WhizzColors.border,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.md),
          borderSide: BorderSide(
            color: WhizzColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.md),
          borderSide: BorderSide(
            color: WhizzColors.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.md),
          borderSide: BorderSide(
            color: WhizzColors.error,
            width: 2,
          ),
        ),
      ),
    );
  }

  /// Create a consistent loading indicator
  static Widget loadingIndicator({
    Color? color,
    double? size,
    double? strokeWidth,
  }) {
    return SizedBox(
      width: size ?? GoldenRatio.xl,
      height: size ?? GoldenRatio.xl,
      child: CircularProgressIndicator(
        color: color ?? WhizzColors.primary,
        strokeWidth: strokeWidth ?? 3,
      ),
    );
  }

  /// Create a consistent snackbar
  static SnackBar snackBar({
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    Color backgroundColor;
    Color textColor = Colors.white;
    IconData icon;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = successColor;
        icon = Icons.check_circle;
        break;
      case SnackBarType.error:
        backgroundColor = errorColor;
        icon = Icons.error;
        break;
      case SnackBarType.warning:
        backgroundColor = warningColor;
        icon = Icons.warning;
        break;
      case SnackBarType.info:
        backgroundColor = infoColor;
        icon = Icons.info;
        break;
    }

    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: textColor, size: GoldenRatio.md),
          SizedBox(width: GoldenRatio.sm),
          Expanded(
            child: Text(
              message,
              style: TypographySystem.bodyMedium.copyWith(color: textColor),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      duration: duration ?? const Duration(seconds: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GoldenRatio.md),
      ),
      margin: EdgeInsets.all(GoldenRatio.md),
      behavior: SnackBarBehavior.floating,
      action: actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: textColor,
              onPressed: onActionPressed ?? () {},
            )
          : null,
    );
  }

  /// Show a consistent snackbar
  static void showSnackBar(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      snackBar(
        message: message,
        type: type,
        duration: duration,
        actionLabel: actionLabel,
        onActionPressed: onActionPressed,
      ),
    );
  }
}

/// Snackbar types for consistent messaging
enum SnackBarType {
  success,
  error,
  warning,
  info,
}

/// Extension on BuildContext for easy design system access
extension DesignSystemExtension on BuildContext {
  /// Quick access to design tokens
  Color get primaryColor => DesignSystem.primaryColor;
  Color get secondaryColor => DesignSystem.secondaryColor;
  Color get errorColor => DesignSystem.errorColor;
  Color get successColor => DesignSystem.successColor;
  Color get warningColor => DesignSystem.warningColor;
  Color get infoColor => DesignSystem.infoColor;

  /// Quick access to measurements
  double get borderRadius => DesignSystem.borderRadius;
  double get elevation => DesignSystem.elevation;
  double get iconSize => DesignSystem.iconSize;
  double get buttonHeight => DesignSystem.buttonHeight;
  EdgeInsets get padding => DesignSystem.padding;
}
