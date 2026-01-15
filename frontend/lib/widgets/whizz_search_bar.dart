import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/design_system/golden_ratio_constants.dart';
import '../core/design_system/typography_system.dart';
import '../core/theme/whizz_colors.dart';

/// WhizzSearchBar - A reusable search bar component with rounded corners
///
/// Features:
/// - Rounded corners using golden ratio spacing
/// - Yellow brand color accents on focus
/// - Clear button when text is entered
/// - Material 3 styling with consistent design system
/// - Haptic feedback support
/// - Customizable prefix/suffix icons
///
/// Example:
/// ```dart
/// WhizzSearchBar(
///   controller: searchController,
///   hintText: 'Search products...',
///   onChanged: (value) => setState(() => searchQuery = value),
/// )
/// ```
class WhizzSearchBar extends StatefulWidget {
  /// Controller for the search text field
  final TextEditingController controller;

  /// Hint text to display when field is empty
  final String hintText;

  /// Callback when search text changes
  final ValueChanged<String>? onChanged;

  /// Callback when search is submitted
  final ValueChanged<String>? onSubmitted;

  /// Custom prefix icon (defaults to search icon)
  final IconData? prefixIcon;

  /// Custom suffix icon (overrides clear button)
  final Widget? suffixIcon;

  /// Enable/disable the search bar
  final bool enabled;

  /// Custom text style
  final TextStyle? style;

  /// Custom hint text style
  final TextStyle? hintStyle;

  /// Enable haptic feedback on clear button tap
  final bool enableHapticFeedback;

  /// Border radius for rounded corners (defaults to golden ratio)
  final BorderRadius? borderRadius;

  /// Background color (defaults to white)
  final Color? backgroundColor;

  /// Focus color for border (defaults to brandYellow)
  final Color? focusColor;

  const WhizzSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.style,
    this.hintStyle,
    this.enableHapticFeedback = true,
    this.borderRadius,
    this.backgroundColor,
    this.focusColor,
  });

  @override
  State<WhizzSearchBar> createState() => _WhizzSearchBarState();
}

class _WhizzSearchBarState extends State<WhizzSearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
    _hasText = widget.controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _hasFocus = _focusNode.hasFocus;
    });
  }

  void _onTextChange() {
    final hasText = widget.controller.text.isNotEmpty;
    if (_hasText != hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _clearSearch() {
    if (widget.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }
    widget.controller.clear();
    widget.onChanged?.call('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius =
        widget.borderRadius ?? BorderRadius.circular(GoldenRatio.spacing24);
    final backgroundColor = widget.backgroundColor ?? WhizzColors.white;
    final focusColor = widget.focusColor ?? WhizzColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: _hasFocus
                ? focusColor.withValues(alpha: 0.12)
                : WhizzColors.black.withValues(alpha: 0.04),
            blurRadius: _hasFocus ? 12 : 8,
            offset: Offset(0, _hasFocus ? 4 : 2),
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        style: (widget.style ?? TypographySystem.bodyLarge).copyWith(
          color: widget.enabled ? WhizzColors.grey900 : WhizzColors.grey500,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: (widget.hintStyle ?? TypographySystem.bodyMedium).copyWith(
            color: WhizzColors.grey500,
          ),
          prefixIcon: Icon(
            widget.prefixIcon ?? Icons.search,
            color: _hasFocus
                ? focusColor
                : widget.enabled
                    ? WhizzColors.grey600
                    : WhizzColors.grey400,
            size: GoldenRatio.iconMd, // 20px - elegant, Uber/Airbnb style
          ),
          suffixIcon: widget.suffixIcon ??
              (_hasText
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: WhizzColors.grey600,
                        size: GoldenRatio.iconSm, // 16px - elegant clear icon
                      ),
                      onPressed: widget.enabled ? _clearSearch : null,
                      tooltip: 'Clear search',
                    )
                  : null),
          border: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(
              color: WhizzColors.grey300,
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(
              color: WhizzColors.grey300,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(
              color: focusColor,
              width: 2,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(
              color: WhizzColors.grey200,
              width: 1,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: GoldenRatio.spacing16,
            vertical: GoldenRatio.spacing12,
          ),
          filled: true,
          fillColor: widget.enabled ? backgroundColor : WhizzColors.grey100,
        ),
      ),
    );
  }
}

/// WhizzSearchBarCompact - A more compact version for toolbars and app bars
class WhizzSearchBarCompact extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  const WhizzSearchBarCompact({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return WhizzSearchBar(
      controller: controller,
      hintText: hintText,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      borderRadius: BorderRadius.circular(GoldenRatio.spacing20),
      style: TypographySystem.bodyMedium,
    );
  }
}
