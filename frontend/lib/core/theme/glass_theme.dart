import 'dart:ui' show lerpDouble;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'whizz_colors.dart';

/// Theme extension that stores glass-surface defaults for each brightness.
@immutable
class GlassThemeData extends ThemeExtension<GlassThemeData> {
  final Color baseColor;
  final Color borderColor;
  final double backgroundOpacity;
  final double blurSigma;
  final List<BoxShadow> shadows;

  const GlassThemeData({
    required this.baseColor,
    required this.borderColor,
    required this.backgroundOpacity,
    required this.blurSigma,
    required this.shadows,
  });

  GlassThemeData.light()
      : this(
          baseColor: WhizzColors.white,
          borderColor: WhizzColors.secondary,
          backgroundOpacity: 0.72,
          blurSigma: 24,
          shadows: [
            BoxShadow(
              color: WhizzColors.shadow.withValues(alpha: 0.04),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: WhizzColors.shadow.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        );

  GlassThemeData.dark()
      : this(
          baseColor: WhizzColors.secondary,
          borderColor: WhizzColors.white,
          backgroundOpacity: 0.35,
          blurSigma: 32,
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
          ],
        );

  Color overlayColor([double? opacity]) {
    final effectiveOpacity = opacity ?? backgroundOpacity;
    return baseColor.withValues(alpha: effectiveOpacity);
  }

  Color outlineColor([double multiplier = 0.12]) {
    return borderColor.withValues(alpha: multiplier);
  }

  @override
  GlassThemeData copyWith({
    Color? baseColor,
    Color? borderColor,
    double? backgroundOpacity,
    double? blurSigma,
    List<BoxShadow>? shadows,
  }) {
    return GlassThemeData(
      baseColor: baseColor ?? this.baseColor,
      borderColor: borderColor ?? this.borderColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      blurSigma: blurSigma ?? this.blurSigma,
      shadows: shadows ?? this.shadows,
    );
  }

  @override
  GlassThemeData lerp(ThemeExtension<GlassThemeData>? other, double t) {
    if (other is! GlassThemeData) return this;
    return GlassThemeData(
      baseColor: Color.lerp(baseColor, other.baseColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      backgroundOpacity:
          lerpDouble(backgroundOpacity, other.backgroundOpacity, t)!,
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t)!,
      shadows: BoxShadow.lerpList(shadows, other.shadows, t) ?? shadows,
    );
  }
}
