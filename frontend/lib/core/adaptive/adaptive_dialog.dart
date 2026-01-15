import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'platform_detector.dart';
import '../theme/whizz_colors.dart';

/// Shows an adaptive dialog based on the platform
Future<T?> showAdaptiveDialog<T>({
  required BuildContext context,
  required String title,
  required String content,
  String? confirmText,
  String? cancelText,
  bool barrierDismissible = true,
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
  bool isDestructive = false,
}) {
  if (PlatformDetector.isIOS) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          if (cancelText != null)
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(context).pop();
                onCancel?.call();
              },
              child: Text(cancelText),
            ),
          if (confirmText != null)
            CupertinoDialogAction(
              isDestructiveAction: isDestructive,
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm?.call();
              },
              child: Text(confirmText),
            ),
        ],
      ),
    );
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      actions: [
        if (cancelText != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onCancel?.call();
            },
            child: Text(
              cancelText,
              style: TextStyle(color: WhizzColors.grey600),
            ),
          ),
        if (confirmText != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm?.call();
            },
            child: Text(
              confirmText,
              style: TextStyle(
                color: isDestructive ? WhizzColors.error : WhizzColors.primary,
              ),
            ),
          ),
      ],
    ),
  );
}

/// Shows an adaptive action sheet / bottom sheet
Future<T?> showAdaptiveActionSheet<T>({
  required BuildContext context,
  required String title,
  String? message,
  required List<AdaptiveActionSheetAction> actions,
  bool barrierDismissible = true,
  String? cancelText,
}) {
  if (PlatformDetector.isIOS) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        message: message != null ? Text(message) : null,
        actions: actions
            .map((action) => CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.of(context).pop();
                    action.onPressed?.call();
                  },
                  isDestructiveAction: action.isDestructive,
                  isDefaultAction: action.isDefault,
                  child: Text(action.label),
                ))
            .toList(),
        cancelButton: cancelText != null
            ? CupertinoActionSheetAction(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(cancelText),
              )
            : null,
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isDismissible: barrierDismissible,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: WhizzColors.secondary,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: WhizzColors.grey600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          // Actions
          ...actions.map((action) => ListTile(
                title: Text(
                  action.label,
                  style: TextStyle(
                    color: action.isDestructive
                        ? WhizzColors.error
                        : (action.isDefault
                            ? WhizzColors.primary
                            : WhizzColors.secondary),
                    fontWeight:
                        action.isDefault ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  action.onPressed?.call();
                },
              )),
          if (cancelText != null) ...[
            const Divider(height: 1),
            ListTile(
              title: Text(
                cancelText,
                style: TextStyle(
                  color: WhizzColors.grey600,
                ),
              ),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Action for adaptive action sheet
class AdaptiveActionSheetAction {
  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;
  final bool isDefault;

  const AdaptiveActionSheetAction({
    required this.label,
    this.onPressed,
    this.isDestructive = false,
    this.isDefault = false,
  });
}

/// Shows an adaptive loading dialog
Future<T?> showAdaptiveLoadingDialog<T>({
  required BuildContext context,
  String? message,
}) {
  if (PlatformDetector.isIOS) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: WhizzColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(radius: 16),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: WhizzColors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(WhizzColors.primary),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Shows an adaptive snackbar / toast
void showAdaptiveSnackBar({
  required BuildContext context,
  required String message,
  AdaptiveSnackBarType type = AdaptiveSnackBarType.info,
  Duration duration = const Duration(seconds: 3),
  VoidCallback? onAction,
  String? actionLabel,
}) {
  final color = switch (type) {
    AdaptiveSnackBarType.success => WhizzColors.success,
    AdaptiveSnackBarType.error => WhizzColors.error,
    AdaptiveSnackBarType.warning => WhizzColors.warning,
    AdaptiveSnackBarType.info => WhizzColors.secondary,
  };

  final icon = switch (type) {
    AdaptiveSnackBarType.success => PlatformDetector.isIOS
        ? CupertinoIcons.check_mark_circled
        : Icons.check_circle,
    AdaptiveSnackBarType.error =>
      PlatformDetector.isIOS ? CupertinoIcons.xmark_circle : Icons.error,
    AdaptiveSnackBarType.warning => PlatformDetector.isIOS
        ? CupertinoIcons.exclamationmark_triangle
        : Icons.warning,
    AdaptiveSnackBarType.info =>
      PlatformDetector.isIOS ? CupertinoIcons.info_circle : Icons.info,
  };

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: WhizzColors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: color,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      action: onAction != null && actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: WhizzColors.white,
              onPressed: onAction,
            )
          : null,
    ),
  );
}

/// Snackbar type for adaptive snackbar
enum AdaptiveSnackBarType {
  success,
  error,
  warning,
  info,
}
