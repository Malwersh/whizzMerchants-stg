import 'package:flutter/material.dart';

import '../core/design_system/design_system.dart';

/// Gradient background that mimics the new iOS glass layers.
class GlassBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showAccentGlow;

  const GlassBackground({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.showAccentGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final accentGradient = RadialGradient(
      colors: [
        WhizzColors.primary.withValues(alpha: 0.35),
        WhizzColors.primary.withValues(alpha: 0.0),
      ],
      radius: 0.55,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            WhizzColors.secondary.withValues(alpha: 0.9),
            WhizzColors.secondary.withValues(alpha: 0.65),
            WhizzColors.primary.withValues(alpha: 0.25),
            WhizzColors.white,
          ],
        ),
      ),
      child: Padding(
        padding: padding,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showAccentGlow)
              Positioned(
                top: -140,
                right: -60,
                width: 320,
                height: 320,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: accentGradient),
                ),
              ),
            if (showAccentGlow)
              Positioned(
                bottom: -120,
                left: -40,
                width: 280,
                height: 280,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: accentGradient.center,
                      radius: accentGradient.radius,
                      colors: [
                        WhizzColors.secondary.withValues(alpha: 0.45),
                        WhizzColors.secondary.withValues(alpha: 0),
                      ],
                      stops: accentGradient.stops,
                    ),
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    WhizzColors.white.withValues(alpha: 0.2),
                    WhizzColors.white.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
