import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/design_system/design_system.dart';

class WizzBusinessTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;

  const WizzBusinessTextFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      enabled: enabled,
      textDirection: TextDirection.ltr, // Always left-to-right
      style: TypographySystem.bodyMedium,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: enabled ? WhizzColors.surface : WhizzColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: GoldenRatio.md,
          vertical: GoldenRatio.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignSystem.borderRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignSystem.borderRadius),
          borderSide: BorderSide(
            color: WhizzColors.border,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignSystem.borderRadius),
          borderSide: BorderSide(
            color: WhizzColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignSystem.borderRadius),
          borderSide: BorderSide(
            color: DesignSystem.errorColor,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignSystem.borderRadius),
          borderSide: BorderSide(
            color: DesignSystem.errorColor,
            width: 2,
          ),
        ),
        labelStyle: TypographySystem.bodyMedium.copyWith(
          color: WhizzColors.onSurfaceVariant,
        ),
        floatingLabelStyle: TypographySystem.bodyMedium.copyWith(
          color: WhizzColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
