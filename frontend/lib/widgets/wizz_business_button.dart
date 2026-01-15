import 'package:flutter/material.dart';
import '../core/theme/whizz_colors.dart';
import '../core/design_system/golden_ratio_constants.dart';
import '../core/design_system/typography_system.dart';

class WizzBusinessButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;

  const WizzBusinessButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = backgroundColor ?? WhizzColors.primary;
    final buttonTextColor = textColor ?? Colors.white;
    
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? (GoldenRatio.spacing20 * 2.5),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              buttonColor,
              buttonColor == WhizzColors.primary
                  ? WhizzColors.primaryDark
                  : buttonColor.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(GoldenRatio.spacing12),
          boxShadow: [
            BoxShadow(
              color: buttonColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(GoldenRatio.spacing12),
            onTap: isLoading ? null : onPressed,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: GoldenRatio.md,
                      height: GoldenRatio.md,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      text,
                      style: TypographySystem.labelLarge.copyWith(
                        color: buttonTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
