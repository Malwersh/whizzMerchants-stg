import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'platform_detector.dart';
import '../theme/whizz_colors.dart';

/// Adaptive bottom sheet that provides native experience on each platform
/// - iOS: Cupertino modal popup with frosted glass effect
/// - Android: Material bottom sheet with smooth animations
class AdaptiveBottomSheet {
  /// Shows an adaptive bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
    double initialChildSize = 0.9,
    double minChildSize = 0.5,
    double maxChildSize = 0.95,
    bool isScrollControlled = true,
  }) {
    if (PlatformDetector.isIOS) {
      return showCupertinoModalPopup<T>(
        context: context,
        barrierDismissible: isDismissible,
        builder: (context) => _CupertinoBottomSheet(
          builder: builder,
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
        ),
      );
    }

    // Material Design for Android
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        expand: false,
        builder: (context, scrollController) {
          return _MaterialBottomSheet(
            scrollController: scrollController,
            builder: builder,
          );
        },
      ),
    );
  }
}

/// iOS-style bottom sheet with frosted glass effect
class _CupertinoBottomSheet extends StatelessWidget {
  final WidgetBuilder builder;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;

  const _CupertinoBottomSheet({
    required this.builder,
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final initialHeight = screenHeight * initialChildSize;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        // Handle drag to dismiss
        if (details.primaryDelta! > 10) {
          Navigator.of(context).pop();
        }
      },
      child: Container(
        height: initialHeight,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground
                    .resolveFrom(context)
                    .withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Drag indicator
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey3.resolveFrom(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: builder(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Material Design bottom sheet
class _MaterialBottomSheet extends StatelessWidget {
  final ScrollController scrollController;
  final WidgetBuilder builder;

  const _MaterialBottomSheet({
    required this.scrollController,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WhizzColors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: WhizzColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: builder(context),
          ),
        ],
      ),
    );
  }
}

/// Adaptive Form Field wrapper that ensures Material context on Android
/// and native Cupertino styling on iOS
class AdaptiveFormField extends StatelessWidget {
  final Widget child;

  const AdaptiveFormField({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformDetector.isIOS) {
      // iOS doesn't need Material wrapper
      return child;
    }

    // Android needs Material for TextFormField
    return Material(
      color: Colors.transparent,
      child: child,
    );
  }
}

/// Adaptive panel that provides platform-specific styling
class AdaptivePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;

  const AdaptivePanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformDetector.isIOS) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius ?? 16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor ??
                  CupertinoColors.systemBackground
                      .resolveFrom(context)
                      .withOpacity(0.7),
              borderRadius: BorderRadius.circular(borderRadius ?? 16),
              border: Border.all(
                color: CupertinoColors.separator.resolveFrom(context),
                width: 0.5,
              ),
            ),
            child: child,
          ),
        ),
      );
    }

    // Material Design panel for Android
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? WhizzColors.white,
        borderRadius: BorderRadius.circular(borderRadius ?? 16),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
      ),
      child: child,
    );
  }
}
