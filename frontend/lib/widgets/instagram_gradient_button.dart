import 'package:flutter/material.dart';
import '../core/theme/gradient_colors.dart';
import '../core/design_system/golden_ratio_constants.dart';
import '../core/design_system/typography_system.dart';

/// Instagram-style gradient button with modern design
class InstagramGradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final double? height;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;

  const InstagramGradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.gradient,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height,
    this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 56,
      decoration: BoxDecoration(
        gradient: gradient ?? GradientColors.purplePink,
        borderRadius: BorderRadius.circular(borderRadius ?? GoldenRatio.md),
        boxShadow: [
          BoxShadow(
            color: (gradient?.colors.first ?? const Color(0xFF8B5CF6))
                .withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadius ?? GoldenRatio.md),
          child: Container(
            padding: padding ?? EdgeInsets.symmetric(
              horizontal: GoldenRatio.lg,
              vertical: GoldenRatio.md,
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 20),
                          SizedBox(width: GoldenRatio.sm),
                        ],
                        Text(
                          text,
                          style: TypographySystem.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined button with gradient border
class InstagramOutlinedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final IconData? icon;
  final double? width;
  final double? height;
  final double? borderRadius;

  const InstagramOutlinedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.gradient,
    this.icon,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius ?? GoldenRatio.md),
        gradient: gradient ?? GradientColors.purplePink,
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular((borderRadius ?? GoldenRatio.md) - 2),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular((borderRadius ?? GoldenRatio.md) - 2),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: GoldenRatio.lg,
                vertical: GoldenRatio.md,
              ),
              child: Center(
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    return (gradient ?? GradientColors.purplePink)
                        .createShader(bounds);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        SizedBox(width: GoldenRatio.sm),
                      ],
                      Text(
                        text,
                        style: TypographySystem.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
