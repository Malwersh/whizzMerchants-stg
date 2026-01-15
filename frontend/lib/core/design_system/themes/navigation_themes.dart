import 'package:flutter/material.dart';
import '../golden_ratio_constants.dart';
import '../typography_system.dart';
import '../../theme/whizz_colors.dart';

/// Navigation Themes
///
/// Provides consistent navigation styling throughout the app using
/// Material Design 3 patterns with golden ratio proportions.

class NavigationThemes {
  NavigationThemes._();

  // ══════════════════════════════════════════════════════════════════════════
  // APP BAR THEMES
  // ══════════════════════════════════════════════════════════════════════════

  static final AppBarTheme appBarTheme = AppBarTheme(
    backgroundColor: WhizzColors.surface,
    foregroundColor: WhizzColors.onSurface,
    elevation: GoldenRatio.xs,
    shadowColor: WhizzColors.shadow,
    surfaceTintColor: WhizzColors.primary,
    centerTitle: false,
    titleSpacing: GoldenRatio.lg,
    toolbarHeight: GoldenRatio.xxl,
    titleTextStyle: TypographySystem.headlineSmall.copyWith(
      color: WhizzColors.onSurface,
      fontWeight: FontWeight.w500,
    ),
    actionsIconTheme: IconThemeData(
      color: WhizzColors.onSurface,
      size: GoldenRatio.lg,
    ),
    iconTheme: IconThemeData(
      color: WhizzColors.onSurface,
      size: GoldenRatio.lg,
    ),
  );

  static final AppBarTheme primaryAppBarTheme = AppBarTheme(
    backgroundColor: WhizzColors.primary,
    foregroundColor: WhizzColors.onPrimary,
    elevation: GoldenRatio.sm,
    shadowColor: WhizzColors.shadow.withValues(alpha: 0.2),
    surfaceTintColor: WhizzColors.primary,
    centerTitle: false,
    titleSpacing: GoldenRatio.lg,
    toolbarHeight: GoldenRatio.xxl,
    titleTextStyle: TypographySystem.headlineSmall.copyWith(
      color: WhizzColors.onPrimary,
      fontWeight: FontWeight.w600,
    ),
    actionsIconTheme: IconThemeData(
      color: WhizzColors.onPrimary,
      size: GoldenRatio.lg,
    ),
    iconTheme: IconThemeData(
      color: WhizzColors.onPrimary,
      size: GoldenRatio.lg,
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // NAVIGATION BAR THEMES
  // ══════════════════════════════════════════════════════════════════════════

  static final NavigationBarThemeData navigationBarTheme =
      NavigationBarThemeData(
    backgroundColor: WhizzColors.surface,
    indicatorColor: WhizzColors.primary.withValues(alpha: 0.12),
    elevation: GoldenRatio.sm,
    height: GoldenRatio.xxl,
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return TypographySystem.labelMedium.copyWith(
          color: WhizzColors.primary,
          fontWeight: FontWeight.w600,
        );
      }
      return TypographySystem.labelMedium.copyWith(
        color: WhizzColors.onSurfaceVariant,
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return IconThemeData(
          color: WhizzColors.primary,
          size: GoldenRatio.lg,
        );
      }
      return IconThemeData(
        color: WhizzColors.onSurfaceVariant,
        size: GoldenRatio.lg,
      );
    }),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // NAVIGATION DRAWER THEMES
  // ══════════════════════════════════════════════════════════════════════════

  static final DrawerThemeData drawerTheme = DrawerThemeData(
    backgroundColor: WhizzColors.surface,
    elevation: GoldenRatio.md,
    shadowColor: WhizzColors.shadow,
    surfaceTintColor: WhizzColors.surface,
    width: GoldenRatio.baseUnit * 36, // ~288px (golden ratio based)
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topRight: Radius.circular(GoldenRatio.lg),
        bottomRight: Radius.circular(GoldenRatio.lg),
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // LIST TILE THEMES (for navigation items)
  // ══════════════════════════════════════════════════════════════════════════

  static final ListTileThemeData navigationListTileTheme = ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(
      horizontal: GoldenRatio.lg,
      vertical: GoldenRatio.xs,
    ),
    minLeadingWidth: GoldenRatio.xl,
    horizontalTitleGap: GoldenRatio.md,
    minVerticalPadding: GoldenRatio.xs,
    iconColor: WhizzColors.onSurfaceVariant,
    textColor: WhizzColors.onSurface,
    titleTextStyle: TypographySystem.bodyLarge.copyWith(
      color: WhizzColors.onSurface,
      fontWeight: FontWeight.w500,
    ),
    subtitleTextStyle: TypographySystem.bodyMedium.copyWith(
      color: WhizzColors.onSurfaceVariant,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GoldenRatio.md),
    ),
  );

  static final ListTileThemeData selectedNavigationListTileTheme =
      ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(
      horizontal: GoldenRatio.lg,
      vertical: GoldenRatio.xs,
    ),
    minLeadingWidth: GoldenRatio.xl,
    horizontalTitleGap: GoldenRatio.md,
    minVerticalPadding: GoldenRatio.xs,
    iconColor: WhizzColors.primary,
    textColor: WhizzColors.primary,
    titleTextStyle: TypographySystem.bodyLarge.copyWith(
      color: WhizzColors.primary,
      fontWeight: FontWeight.w600,
    ),
    subtitleTextStyle: TypographySystem.bodyMedium.copyWith(
      color: WhizzColors.primary.withValues(alpha: 0.7),
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GoldenRatio.md),
    ),
    tileColor: WhizzColors.primary.withValues(alpha: 0.08),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // TAB BAR THEMES
  // ══════════════════════════════════════════════════════════════════════════

  static final TabBarTheme tabBarTheme = TabBarTheme(
    labelColor: WhizzColors.primary,
    unselectedLabelColor: WhizzColors.onSurfaceVariant,
    labelStyle: TypographySystem.titleSmall.copyWith(
      fontWeight: FontWeight.w600,
    ),
    unselectedLabelStyle: TypographySystem.titleSmall.copyWith(
      fontWeight: FontWeight.w500,
    ),
    indicator: UnderlineTabIndicator(
      borderSide: BorderSide(
        color: WhizzColors.primary,
        width: GoldenRatio.xs / 2,
      ),
      insets: EdgeInsets.symmetric(horizontal: GoldenRatio.lg),
    ),
    indicatorSize: TabBarIndicatorSize.tab,
    dividerColor: WhizzColors.border,
    dividerHeight: 1,
    tabAlignment: TabAlignment.start,
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) {
        return WhizzColors.primary.withValues(alpha: 0.04);
      }
      if (states.contains(WidgetState.pressed)) {
        return WhizzColors.primary.withValues(alpha: 0.08);
      }
      return null;
    }),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ══════════════════════════════════════════════════════════════════════════

  /// Creates a navigation list tile with proper theming
  static Widget createNavigationTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      onTap: onTap,
      selected: isSelected,
      selectedTileColor:
          isSelected ? WhizzColors.primary.withValues(alpha: 0.08) : null,
      iconColor:
          isSelected ? WhizzColors.primary : WhizzColors.onSurfaceVariant,
      textColor: isSelected ? WhizzColors.primary : WhizzColors.onSurface,
      titleTextStyle: isSelected
          ? TypographySystem.bodyLarge.copyWith(
              color: WhizzColors.primary,
              fontWeight: FontWeight.w600,
            )
          : TypographySystem.bodyLarge.copyWith(
              color: WhizzColors.onSurface,
              fontWeight: FontWeight.w500,
            ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GoldenRatio.md),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: GoldenRatio.lg,
        vertical: GoldenRatio.xs,
      ),
    );
  }

  /// Creates a navigation drawer header with proper theming
  static Widget createDrawerHeader({
    required String title,
    String? subtitle,
    Widget? avatar,
  }) {
    return DrawerHeader(
      decoration: BoxDecoration(
        color: WhizzColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(GoldenRatio.lg),
          bottomRight: Radius.circular(GoldenRatio.lg),
        ),
      ),
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(GoldenRatio.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (avatar != null) ...[
            avatar,
            SizedBox(height: GoldenRatio.md),
          ],
          Text(
            title,
            style: TypographySystem.headlineSmall.copyWith(
              color: WhizzColors.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TypographySystem.bodyMedium.copyWith(
                color: WhizzColors.onPrimary.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SPECIALIZED NAVIGATION COMPONENTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Creates a breadcrumb navigation widget
  static Widget breadcrumb({
    required List<String> items,
    Function(int)? onTap,
    String separator = ' / ',
  }) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          GestureDetector(
            onTap: onTap != null ? () => onTap(i) : null,
            child: Text(
              items[i],
              style: i == items.length - 1
                  ? TypographySystem.bodyMedium.copyWith(
                      color: WhizzColors.onSurface,
                      fontWeight: FontWeight.w500,
                    )
                  : TypographySystem.bodyMedium.copyWith(
                      color: WhizzColors.onSurfaceVariant,
                      decoration: TextDecoration.underline,
                    ),
            ),
          ),
          if (i < items.length - 1)
            Text(
              separator,
              style: TypographySystem.bodyMedium.copyWith(
                color: WhizzColors.onSurfaceVariant,
              ),
            ),
        ],
      ],
    );
  }

  /// Creates a pill-style tab bar
  static Widget pillTabBar({
    required List<String> tabs,
    required int selectedIndex,
    required Function(int) onTap,
    Color? selectedColor,
    Color? unselectedColor,
  }) {
    return Container(
      padding: EdgeInsets.all(GoldenRatio.xs),
      decoration: BoxDecoration(
        color: WhizzColors.surfaceVariant,
        borderRadius: BorderRadius.circular(GoldenRatio.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < tabs.length; i++)
            GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: GoldenRatio.md,
                  vertical: GoldenRatio.sm,
                ),
                margin: EdgeInsets.only(
                  right: i < tabs.length - 1 ? GoldenRatio.xs : 0,
                ),
                decoration: BoxDecoration(
                  color: i == selectedIndex
                      ? selectedColor ?? WhizzColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(GoldenRatio.md),
                ),
                child: Text(
                  tabs[i],
                  style: TypographySystem.labelMedium.copyWith(
                    color: i == selectedIndex
                        ? WhizzColors.onPrimary
                        : unselectedColor ?? WhizzColors.onSurfaceVariant,
                    fontWeight: i == selectedIndex
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
