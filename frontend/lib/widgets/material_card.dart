import 'package:flutter/material.dart';
import '../core/theme/whizz_colors.dart';

class MaterialCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? elevation;
  final Color? color;
  final Color? shadowColor;

  const MaterialCard({
    super.key,
    required this.child,
    this.padding,
    this.elevation,
    this.color,
    this.shadowColor,
  });

  const MaterialCard.elevated({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.shadowColor,
  })  : elevation = 4;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation ?? 1,
      color: color ?? WhizzColors.surface,
      shadowColor: shadowColor ?? WhizzColors.onSurface.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );
  }
}
