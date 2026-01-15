import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'platform_detector.dart';
import '../theme/whizz_colors.dart';

/// Adaptive button that automatically switches between CupertinoButton and ElevatedButton
/// based on the platform, while maintaining brand colors.
class AdaptiveButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? color;
  final Color? textColor;
  final bool isDestructive;
  final double? minWidth;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final bool isLoading;

  const AdaptiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color,
    this.textColor,
    this.isDestructive = false,
    this.minWidth,
    this.height,
    this.padding,
    this.isLoading = false,
  });

  /// Primary button with brand yellow color
  factory AdaptiveButton.primary({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    double? minWidth,
    double? height,
    EdgeInsetsGeometry? padding,
    bool isLoading = false,
  }) {
    return AdaptiveButton(
      key: key,
      onPressed: onPressed,
      color: WhizzColors.primary,
      textColor: WhizzColors.secondary,
      minWidth: minWidth,
      height: height,
      padding: padding,
      isLoading: isLoading,
      child: child,
    );
  }

  /// Secondary button with brand blue color
  factory AdaptiveButton.secondary({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    double? minWidth,
    double? height,
    EdgeInsetsGeometry? padding,
    bool isLoading = false,
  }) {
    return AdaptiveButton(
      key: key,
      onPressed: onPressed,
      color: WhizzColors.secondary,
      textColor: WhizzColors.white,
      minWidth: minWidth,
      height: height,
      padding: padding,
      isLoading: isLoading,
      child: child,
    );
  }

  /// Outlined button (transparent background with border)
  static Widget outlined({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    Color? color,
    double? minWidth,
    double? height,
    EdgeInsetsGeometry? padding,
    bool isLoading = false,
  }) {
    return _AdaptiveOutlinedButton(
      key: key,
      onPressed: onPressed,
      color: color ?? WhizzColors.primary,
      minWidth: minWidth,
      height: height,
      padding: padding,
      isLoading: isLoading,
      child: child,
    );
  }

  /// Text button (no background)
  static Widget text({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    Color? color,
    EdgeInsetsGeometry? padding,
    bool isLoading = false,
  }) {
    return _AdaptiveTextButton(
      key: key,
      onPressed: onPressed,
      color: color ?? WhizzColors.primary,
      padding: padding,
      isLoading: isLoading,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor =
        isDestructive ? WhizzColors.error : (color ?? WhizzColors.primary);
    final foregroundColor =
        textColor ?? (isDestructive ? WhizzColors.white : WhizzColors.white);

    if (isLoading) {
      return _buildLoadingButton(context, buttonColor);
    }

    if (PlatformDetector.isIOS) {
      return SizedBox(
        width: minWidth,
        height: height ?? 48,
        child: CupertinoButton.filled(
          onPressed: onPressed,
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          borderRadius: BorderRadius.circular(12),
          disabledColor: WhizzColors.grey400,
          child: DefaultTextStyle(
            style: TextStyle(
              color: foregroundColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            child: child,
          ),
        ),
      );
    }

    // Material Design (Android)
    return SizedBox(
      width: minWidth,
      height: height ?? 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: WhizzColors.grey400,
          disabledForegroundColor: WhizzColors.grey600,
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: child,
      ),
    );
  }

  Widget _buildLoadingButton(BuildContext context, Color buttonColor) {
    if (PlatformDetector.isIOS) {
      return SizedBox(
        width: minWidth,
        height: height ?? 48,
        child: CupertinoButton.filled(
          onPressed: null,
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          borderRadius: BorderRadius.circular(12),
          disabledColor: buttonColor.withValues(alpha: 0.7),
          child: const CupertinoActivityIndicator(color: Colors.white),
        ),
      );
    }

    return SizedBox(
      width: minWidth,
      height: height ?? 48,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor.withValues(alpha: 0.7),
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Outlined button variant
class _AdaptiveOutlinedButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color color;
  final double? minWidth;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final bool isLoading;

  const _AdaptiveOutlinedButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.color,
    this.minWidth,
    this.height,
    this.padding,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingButton(context);
    }

    if (PlatformDetector.isIOS) {
      return SizedBox(
        width: minWidth,
        height: height ?? 48,
        child: CupertinoButton(
          onPressed: onPressed,
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          borderRadius: BorderRadius.circular(12),
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DefaultTextStyle(
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: minWidth,
      height: height ?? 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 2),
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildLoadingButton(BuildContext context) {
    if (PlatformDetector.isIOS) {
      return SizedBox(
        width: minWidth,
        height: height ?? 48,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: CupertinoActivityIndicator(color: color),
          ),
        ),
      );
    }

    return SizedBox(
      width: minWidth,
      height: height ?? 48,
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.5), width: 2),
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ),
    );
  }
}

/// Text button variant
class _AdaptiveTextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry? padding;
  final bool isLoading;

  const _AdaptiveTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.color,
    this.padding,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingButton(context);
    }

    if (PlatformDetector.isIOS) {
      return CupertinoButton(
        onPressed: onPressed,
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: DefaultTextStyle(
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          child: child,
        ),
      );
    }

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: child,
    );
  }

  Widget _buildLoadingButton(BuildContext context) {
    if (PlatformDetector.isIOS) {
      return CupertinoButton(
        onPressed: null,
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: CupertinoActivityIndicator(color: color),
      );
    }

    return TextButton(
      onPressed: null,
      style: TextButton.styleFrom(
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}
