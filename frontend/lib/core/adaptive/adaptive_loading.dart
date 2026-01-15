import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'platform_detector.dart';
import '../theme/whizz_colors.dart';

/// Adaptive loading indicator (spinner/progress)
class AdaptiveLoadingIndicator extends StatelessWidget {
  final Color? color;
  final double? size;

  const AdaptiveLoadingIndicator({
    super.key,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? WhizzColors.primary;

    if (PlatformDetector.isIOS) {
      return CupertinoActivityIndicator(
        color: effectiveColor,
        radius: size != null ? size! / 2 : 10,
      );
    }

    return SizedBox(
      width: size ?? 20,
      height: size ?? 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
      ),
    );
  }
}

/// Adaptive loading indicator with centered layout
class AdaptiveLoadingCenter extends StatelessWidget {
  final String? message;
  final Color? color;

  const AdaptiveLoadingCenter({
    super.key,
    this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AdaptiveLoadingIndicator(color: color),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                fontSize: 14,
                color: WhizzColors.grey600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
