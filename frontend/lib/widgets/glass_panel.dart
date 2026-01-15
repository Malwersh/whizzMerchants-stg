import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/adaptive/platform_detector.dart';
import '../core/design_system/design_system.dart';

/// Glass panel container that uses blur on iOS and softened opacity elsewhere.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double? opacity;
  final double? blurSigma;
  final bool enableBlurOnAndroid;
  final EdgeInsetsGeometry? margin;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 28,
    this.opacity,
    this.blurSigma,
    this.enableBlurOnAndroid = false,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final glassDefaults =
        Theme.of(context).extension<GlassThemeData>() ?? GlassThemeData.light();

    final resolvedOpacity = opacity ?? glassDefaults.backgroundOpacity;
    final resolvedBlur = blurSigma ?? glassDefaults.blurSigma;
    final backgroundColor = glassDefaults.overlayColor(resolvedOpacity);
    final borderColor = glassDefaults.outlineColor(0.18);
    final shouldBlur = PlatformDetector.isIOS || enableBlurOnAndroid;

    Widget content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: glassDefaults.shadows,
      ),
      child: child,
    );

    if (!shouldBlur) {
      return content;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: resolvedBlur, sigmaY: resolvedBlur),
        child: content,
      ),
    );
  }
}
