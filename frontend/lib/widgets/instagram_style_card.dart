import 'package:flutter/material.dart';
import '../core/theme/gradient_colors.dart';
import '../core/design_system/golden_ratio_constants.dart';

/// Instagram-inspired card widget with clean design and gradient support
class InstagramStyleCard extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final bool enableGlassMorphism;

  const InstagramStyleCard({
    super.key,
    required this.child,
    this.gradient,
    this.backgroundColor,
    this.padding,
    this.margin,
    this.borderRadius,
    this.boxShadow,
    this.onTap,
    this.enableGlassMorphism = false,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      padding: padding ?? EdgeInsets.all(GoldenRatio.md),
      decoration: BoxDecoration(
        gradient: gradient,
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(borderRadius ?? GoldenRatio.md),
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: enableGlassMorphism 
        ? Stack(
            children: [
              // Glass morphism overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: GradientColors.glassMorphism,
                    borderRadius: BorderRadius.circular(borderRadius ?? GoldenRatio.md),
                  ),
                ),
              ),
              // Content
              child,
            ],
          )
        : child,
    );

    if (onTap != null) {
      return Container(
        margin: margin,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius ?? GoldenRatio.md),
            child: content,
          ),
        ),
      );
    }

    return Container(
      margin: margin,
      child: content,
    );
  }
}

/// Gradient card with predefined Instagram gradients
class GradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final GradientType gradientType;

  const GradientCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.gradientType = GradientType.purplePink,
  });

  Gradient _getGradient() {
    switch (gradientType) {
      case GradientType.instagram:
        return GradientColors.instagram;
      case GradientType.purplePink:
        return GradientColors.purplePink;
      case GradientType.pinkOrange:
        return GradientColors.pinkOrange;
      case GradientType.orangeYellow:
        return GradientColors.orangeYellow;
      case GradientType.bluePurple:
        return GradientColors.bluePurple;
      case GradientType.greenTeal:
        return GradientColors.greenTeal;
      case GradientType.sunset:
        return GradientColors.sunset;
      case GradientType.ocean:
        return GradientColors.ocean;
      case GradientType.fire:
        return GradientColors.fire;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InstagramStyleCard(
      gradient: _getGradient(),
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: child,
      ),
    );
  }
}

enum GradientType {
  instagram,
  purplePink,
  pinkOrange,
  orangeYellow,
  bluePurple,
  greenTeal,
  sunset,
  ocean,
  fire,
}
