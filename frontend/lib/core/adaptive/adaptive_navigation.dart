import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'platform_detector.dart';
import '../theme/whizz_colors.dart';

/// Adaptive app bar that uses CupertinoNavigationBar on iOS and AppBar on Android
class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final bool automaticallyImplyLeading;

  const AdaptiveAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.backgroundColor,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (PlatformDetector.isIOS) {
      return CupertinoNavigationBar(
        middle: title,
        leading: leading,
        trailing: actions != null && actions!.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: actions!,
              )
            : null,
        backgroundColor: backgroundColor ?? WhizzColors.white,
        border: Border(
          bottom: BorderSide(
            color: WhizzColors.grey200,
            width: 0.5,
          ),
        ),
        automaticallyImplyLeading: automaticallyImplyLeading,
      );
    }

    return AppBar(
      title: title,
      leading: leading,
      actions: actions,
      backgroundColor: backgroundColor ?? WhizzColors.white,
      foregroundColor: WhizzColors.secondary,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: WhizzColors.grey200,
          height: 1,
        ),
      ),
      automaticallyImplyLeading: automaticallyImplyLeading,
    );
  }
}

/// Adaptive scaffold that handles platform-specific navigation
class AdaptiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Color? backgroundColor;

  const AdaptiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformDetector.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: appBar is CupertinoNavigationBar
            ? appBar as CupertinoNavigationBar
            : null,
        backgroundColor: backgroundColor ?? WhizzColors.white,
        child: body,
      );
    }

    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      drawer: drawer,
      backgroundColor: backgroundColor ?? WhizzColors.white,
    );
  }
}

/// Adaptive bottom navigation bar
class AdaptiveBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AdaptiveBottomNavigationItem> items;

  const AdaptiveBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformDetector.isIOS) {
      return CupertinoTabBar(
        currentIndex: currentIndex,
        onTap: onTap,
        activeColor: WhizzColors.primary,
        inactiveColor: WhizzColors.grey600,
        backgroundColor: WhizzColors.white,
        border: Border(
          top: BorderSide(
            color: WhizzColors.grey200,
            width: 0.5,
          ),
        ),
        items: items
            .map((item) => BottomNavigationBarItem(
                  icon: item.icon,
                  activeIcon: item.activeIcon ?? item.icon,
                  label: item.label,
                ))
            .toList(),
      );
    }

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      selectedItemColor: WhizzColors.primary,
      unselectedItemColor: WhizzColors.grey600,
      backgroundColor: WhizzColors.white,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      items: items
          .map((item) => BottomNavigationBarItem(
                icon: item.icon,
                activeIcon: item.activeIcon ?? item.icon,
                label: item.label,
              ))
          .toList(),
    );
  }
}

/// Item for adaptive bottom navigation
class AdaptiveBottomNavigationItem {
  final Widget icon;
  final Widget? activeIcon;
  final String label;

  const AdaptiveBottomNavigationItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

/// Adaptive back button
class AdaptiveBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;

  const AdaptiveBackButton({
    super.key,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? WhizzColors.secondary;

    if (PlatformDetector.isIOS) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed ?? () => Navigator.of(context).pop(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.back,
              color: effectiveColor,
            ),
          ],
        ),
      );
    }

    return IconButton(
      icon: Icon(Icons.arrow_back, color: effectiveColor),
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
    );
  }
}
