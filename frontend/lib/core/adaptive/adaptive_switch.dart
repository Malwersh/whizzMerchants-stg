import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'platform_detector.dart';
import '../theme/whizz_colors.dart';

/// Adaptive switch that uses CupertinoSwitch on iOS and Switch on Android
class AdaptiveSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final Color? trackColor;

  const AdaptiveSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = activeColor ?? WhizzColors.primary;

    if (PlatformDetector.isIOS) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: effectiveActiveColor,
        inactiveTrackColor: trackColor,
      );
    }

    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: effectiveActiveColor,
      activeTrackColor: effectiveActiveColor.withValues(alpha: 0.5),
      inactiveTrackColor: trackColor ?? WhizzColors.grey200,
    );
  }
}

/// Adaptive switch list tile
class AdaptiveSwitchListTile extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? secondary;
  final Color? activeColor;

  const AdaptiveSwitchListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.secondary,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformDetector.isIOS) {
      return ListTile(
        leading: secondary,
        title: title,
        subtitle: subtitle,
        trailing: CupertinoSwitch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: activeColor ?? WhizzColors.primary,
        ),
        onTap: onChanged != null ? () => onChanged!(!value) : null,
      );
    }

    return SwitchListTile(
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
      secondary: secondary,
      activeColor: activeColor ?? WhizzColors.primary,
      activeTrackColor:
          (activeColor ?? WhizzColors.primary).withValues(alpha: 0.5),
    );
  }
}
