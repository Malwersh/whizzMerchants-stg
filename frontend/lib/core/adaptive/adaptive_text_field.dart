import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'platform_detector.dart';
import '../theme/whizz_colors.dart';

/// Adaptive text field that switches between CupertinoTextField and TextField
/// based on the platform, while maintaining brand styling.
class AdaptiveTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? placeholder;
  final String? label;
  final String? hintText;
  final String? errorText;
  final String? helperText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final bool autofocus;
  final EdgeInsetsGeometry? padding;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;

  const AdaptiveTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.label,
    this.hintText,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.focusNode,
    this.autofocus = false,
    this.padding,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
  });

  /// Email text field with appropriate keyboard and validation
  factory AdaptiveTextField.email({
    Key? key,
    TextEditingController? controller,
    String? placeholder,
    String? label,
    String? errorText,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    FocusNode? focusNode,
    bool autofocus = false,
  }) {
    return AdaptiveTextField(
      key: key,
      controller: controller,
      placeholder: placeholder ?? 'Email',
      label: label,
      errorText: errorText,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      focusNode: focusNode,
      autofocus: autofocus,
      textCapitalization: TextCapitalization.none,
      prefixIcon: Icon(
        PlatformDetector.isIOS ? CupertinoIcons.mail : Icons.email_outlined,
        color: WhizzColors.grey600,
      ),
    );
  }

  /// Password text field with show/hide toggle
  static Widget password({
    Key? key,
    TextEditingController? controller,
    String? placeholder,
    String? label,
    String? errorText,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    FocusNode? focusNode,
    bool autofocus = false,
    required bool obscureText,
    required VoidCallback onToggleObscure,
  }) {
    return _AdaptivePasswordTextField(
      key: key,
      controller: controller,
      placeholder: placeholder ?? 'Password',
      label: label,
      errorText: errorText,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      focusNode: focusNode,
      autofocus: autofocus,
      obscureText: obscureText,
      onToggleObscure: onToggleObscure,
    );
  }

  /// Phone number text field with appropriate keyboard
  factory AdaptiveTextField.phone({
    Key? key,
    TextEditingController? controller,
    String? placeholder,
    String? label,
    String? errorText,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    FocusNode? focusNode,
  }) {
    return AdaptiveTextField(
      key: key,
      controller: controller,
      placeholder: placeholder ?? 'Phone Number',
      label: label,
      errorText: errorText,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      focusNode: focusNode,
      prefixIcon: Icon(
        PlatformDetector.isIOS ? CupertinoIcons.phone : Icons.phone_outlined,
        color: WhizzColors.grey600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformDetector.isIOS) {
      return _buildCupertinoTextField(context);
    }
    return _buildMaterialTextField(context);
  }

  Widget _buildCupertinoTextField(BuildContext context) {
    final textField = CupertinoTextField(
      controller: controller,
      placeholder: placeholder ?? hintText,
      prefix: prefixIcon != null
          ? Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: prefixIcon,
            )
          : null,
      suffix: suffixIcon != null
          ? Padding(
              padding: const EdgeInsets.only(right: 12),
              child: suffixIcon,
            )
          : null,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      readOnly: readOnly,
      enabled: enabled,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      focusNode: focusNode,
      autofocus: autofocus,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      textCapitalization: textCapitalization,
      textAlign: textAlign,
      style: const TextStyle(
        fontSize: 16,
        color: CupertinoColors.black,
      ),
      placeholderStyle: TextStyle(
        fontSize: 16,
        color: WhizzColors.grey600,
      ),
      decoration: BoxDecoration(
        color: enabled ? WhizzColors.white : WhizzColors.grey50,
        border: Border.all(
          color: errorText != null ? WhizzColors.error : WhizzColors.grey400,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    if (label != null || errorText != null || helperText != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: WhizzColors.secondary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          textField,
          if (errorText != null) ...[
            const SizedBox(height: 6),
            Text(
              errorText!,
              style: TextStyle(
                fontSize: 12,
                color: WhizzColors.error,
              ),
            ),
          ],
          if (helperText != null && errorText == null) ...[
            const SizedBox(height: 6),
            Text(
              helperText!,
              style: TextStyle(
                fontSize: 12,
                color: WhizzColors.grey600,
              ),
            ),
          ],
        ],
      );
    }

    return textField;
  }

  Widget _buildMaterialTextField(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: placeholder ?? hintText,
        errorText: errorText,
        helperText: helperText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: enabled ? WhizzColors.white : WhizzColors.grey50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: WhizzColors.grey400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: WhizzColors.grey400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: WhizzColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: WhizzColors.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: WhizzColors.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: WhizzColors.grey400),
        ),
        contentPadding:
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: TextStyle(color: WhizzColors.secondary),
        hintStyle: TextStyle(color: WhizzColors.grey600),
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      readOnly: readOnly,
      enabled: enabled,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      focusNode: focusNode,
      autofocus: autofocus,
      textCapitalization: textCapitalization,
      textAlign: textAlign,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.black,
      ),
    );
  }
}

/// Password text field with show/hide toggle
class _AdaptivePasswordTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? placeholder;
  final String? label;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool obscureText;
  final VoidCallback onToggleObscure;

  const _AdaptivePasswordTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.label,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    required this.obscureText,
    required this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    final prefixIcon = Icon(
      PlatformDetector.isIOS ? CupertinoIcons.lock : Icons.lock_outlined,
      color: WhizzColors.grey600,
    );

    final suffixIcon = GestureDetector(
      onTap: onToggleObscure,
      child: Icon(
        obscureText
            ? (PlatformDetector.isIOS
                ? CupertinoIcons.eye_slash
                : Icons.visibility_off)
            : (PlatformDetector.isIOS ? CupertinoIcons.eye : Icons.visibility),
        color: WhizzColors.grey600,
      ),
    );

    return AdaptiveTextField(
      controller: controller,
      placeholder: placeholder,
      label: label,
      errorText: errorText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      obscureText: obscureText,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      focusNode: focusNode,
      autofocus: autofocus,
      textCapitalization: TextCapitalization.none,
    );
  }
}
