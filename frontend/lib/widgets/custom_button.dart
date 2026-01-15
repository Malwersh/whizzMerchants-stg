import 'package:flutter/material.dart';
import '../core/theme/whizz_colors.dart';
import '../core/design_system/golden_ratio_constants.dart';
import '../core/design_system/typography_system.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final IconData? icon;
  final EdgeInsetsGeometry? padding;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 56,
    this.icon,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = backgroundColor ?? WhizzColors.primary;
    final onPrimaryColor = textColor ?? Colors.white;

    return SizedBox(
      width: width,
      height: height,
      child: isOutlined
          ? _buildOutlinedButton(primaryColor)
          : _buildElevatedButton(primaryColor, onPrimaryColor),
    );
  }

  Widget _buildElevatedButton(Color primaryColor, Color onPrimaryColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            primaryColor == WhizzColors.primary
                ? WhizzColors.primaryDark
                : primaryColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(GoldenRatio.spacing12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
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
          child: Container(
            padding: padding ??
                EdgeInsets.symmetric(
                  horizontal: GoldenRatio.spacing16,
                  vertical: GoldenRatio.spacing12,
                ),
            child: _buildButtonContent(onPrimaryColor, true),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GoldenRatio.spacing12),
        border: Border.all(
          color: primaryColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(GoldenRatio.spacing12),
          onTap: isLoading ? null : onPressed,
          child: Container(
            padding: padding ??
                EdgeInsets.symmetric(
                  horizontal: GoldenRatio.spacing16,
                  vertical: GoldenRatio.spacing12,
                ),
            child: _buildButtonContent(primaryColor, false),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonContent(Color color, bool isElevated) {
    if (isLoading) {
      return SizedBox(
        width: GoldenRatio.md,
        height: GoldenRatio.md,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            isElevated ? Colors.white : color,
          ),
        ),
      );
    }

    final textStyle = TypographySystem.labelLarge.copyWith(
      color: isElevated ? Colors.white : color,
      fontWeight: FontWeight.bold,
    );

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: GoldenRatio.md,
            color: isElevated ? Colors.white : color,
          ),
          SizedBox(width: GoldenRatio.spacing8),
          Text(text, style: textStyle),
        ],
      );
    }

    return Text(text, style: textStyle);
  }
}
