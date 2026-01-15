import 'package:flutter/material.dart';

/// Design System - Component Dimensions
///
/// Standardized dimensions for UI components following Material Design 3.
/// All values are in logical pixels (dp).
///
/// Usage:
/// ```dart
/// height: AppDimensions.buttonHeightLarge,           // 48dp
/// borderRadius: AppDimensions.borderRadiusMedium,    // 12dp
/// iconSize: AppDimensions.iconSizeMedium,            // 24dp
/// ```
class AppDimensions {
  AppDimensions._(); // Private constructor

  // ============================================================================
  // BUTTON DIMENSIONS
  // ============================================================================

  /// Small button height - 32dp (Compact actions)
  static const double buttonHeightSmall = 32.0;

  /// Medium button height - 40dp (Secondary actions)
  static const double buttonHeightMedium = 40.0;

  /// Large button height - 44dp (Standard - Uber/Airbnb style)
  static const double buttonHeightLarge = 44.0;

  /// Extra large button height - 48dp (Primary CTAs)
  static const double buttonHeightExtraLarge = 48.0;

  /// Minimum button width - 64dp
  static const double buttonMinWidth = 64.0;

  /// Small button padding
  static const EdgeInsets buttonPaddingSmall = EdgeInsets.symmetric(
    horizontal: 12.0,
    vertical: 6.0,
  );

  /// Medium button padding
  static const EdgeInsets buttonPaddingMedium = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 10.0,
  );

  /// Large button padding
  static const EdgeInsets buttonPaddingLarge = EdgeInsets.symmetric(
    horizontal: 24.0,
    vertical: 12.0,
  );

  /// Extra large button padding
  static const EdgeInsets buttonPaddingExtraLarge = EdgeInsets.symmetric(
    horizontal: 32.0,
    vertical: 16.0,
  );

  // ============================================================================
  // INPUT FIELD DIMENSIONS
  // ============================================================================

  /// Standard input field height - 44dp (Elegant, modern)
  static const double inputHeight = 44.0;

  /// Compact input field height - 40dp
  static const double inputHeightCompact = 40.0;

  /// Medium input field height - 48dp (Emphasized fields)
  static const double inputHeightMedium = 48.0;

  /// Input field padding
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 12.0,
  );

  /// Compact input field padding
  static const EdgeInsets inputPaddingCompact = EdgeInsets.symmetric(
    horizontal: 12.0,
    vertical: 8.0,
  );

  /// Input field content padding (inside decoration)
  static const EdgeInsets inputContentPadding = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 12.0,
  );

  // ============================================================================
  // CARD DIMENSIONS
  // ============================================================================

  /// Standard card padding - 16dp
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);

  /// Large card padding - 24dp
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(24.0);

  /// Compact card padding - 12dp
  static const EdgeInsets cardPaddingCompact = EdgeInsets.all(12.0);

  /// Card margin (spacing between cards) - 8dp
  static const EdgeInsets cardMargin = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 8.0,
  );

  /// Minimum card height
  static const double cardMinHeight = 80.0;

  // ============================================================================
  // BOTTOM SHEET DIMENSIONS
  // ============================================================================

  /// Handle width - 32dp
  static const double bottomSheetHandleWidth = 32.0;

  /// Handle height - 4dp
  static const double bottomSheetHandleHeight = 4.0;

  /// Maximum height as percentage of screen - 0.9 (90%)
  static const double bottomSheetMaxHeightPercent = 0.9;

  /// Minimum height as percentage of screen - 0.25 (25%)
  static const double bottomSheetMinHeightPercent = 0.25;

  /// Bottom sheet padding - 24dp
  static const EdgeInsets bottomSheetPadding = EdgeInsets.all(24.0);

  /// Bottom sheet top padding (with handle) - 32dp
  static const EdgeInsets bottomSheetPaddingWithHandle = EdgeInsets.only(
    left: 24.0,
    right: 24.0,
    top: 32.0,
    bottom: 24.0,
  );

  // ============================================================================
  // DIALOG DIMENSIONS
  // ============================================================================

  /// Maximum dialog width - 560dp
  static const double dialogMaxWidth = 560.0;

  /// Minimum dialog width - 280dp
  static const double dialogMinWidth = 280.0;

  /// Dialog padding - 24dp
  static const EdgeInsets dialogPadding = EdgeInsets.all(24.0);

  /// Dialog title padding
  static const EdgeInsets dialogTitlePadding = EdgeInsets.only(
    left: 24.0,
    right: 24.0,
    top: 24.0,
    bottom: 16.0,
  );

  /// Dialog content padding
  static const EdgeInsets dialogContentPadding = EdgeInsets.symmetric(
    horizontal: 24.0,
    vertical: 16.0,
  );

  /// Dialog actions padding
  static const EdgeInsets dialogActionsPadding = EdgeInsets.only(
    left: 24.0,
    right: 24.0,
    bottom: 24.0,
    top: 8.0,
  );

  // ============================================================================
  // ICON SIZES (Elegant, Uber/Airbnb-inspired)
  // ============================================================================

  /// Extra small icon - 12dp (tiny inline icons)
  static const double iconSizeXS = 12.0;

  /// Small icon - 16dp (small UI elements)
  static const double iconSizeSM = 16.0;

  /// Medium icon - 20dp (standard, most common - Uber/Airbnb style)
  static const double iconSizeMD = 20.0;

  /// Large icon - 24dp (emphasized elements)
  static const double iconSizeLG = 24.0;

  /// Extra large icon - 32dp (feature cards)
  static const double iconSizeXL = 32.0;

  /// Extra extra large icon - 48dp (hero sections)
  static const double iconSizeXXL = 48.0;

  /// Extra extra extra large icon - 64dp (empty states only)
  static const double iconSizeXXXL = 64.0;

  // ============================================================================
  // TOUCH TARGET SIZES (Accessibility)
  // ============================================================================

  /// Minimum touch target size (WCAG AA) - 44dp
  static const double touchTargetMinimum = 44.0;

  /// Recommended touch target size (Material Design) - 48dp
  static const double touchTargetRecommended = 48.0;

  /// Comfortable touch target size - 56dp
  static const double touchTargetComfortable = 56.0;

  /// Large touch target size - 64dp
  static const double touchTargetLarge = 64.0;

  // ============================================================================
  // BORDER RADIUS
  // ============================================================================

  /// No radius - 0dp
  static const double borderRadiusNone = 0.0;

  /// Extra small radius - 4dp (chips, small elements)
  static const double borderRadiusXS = 4.0;

  /// Small radius - 8dp (buttons, inputs, small cards)
  static const double borderRadiusSM = 8.0;

  /// Medium radius - 12dp (standard cards)
  static const double borderRadiusMD = 12.0;

  /// Large radius - 16dp (large cards, sections)
  static const double borderRadiusLG = 16.0;

  /// Extra large radius - 24dp (bottom sheets top corners)
  static const double borderRadiusXL = 24.0;

  /// Extra extra large radius - 28dp (dialogs, modals)
  static const double borderRadiusXXL = 28.0;

  /// Full radius - 999dp (pills, circular)
  static const double borderRadiusFull = 999.0;

  // Convenience getters for BorderRadius objects
  static BorderRadius get borderRadiusNoneValue =>
      BorderRadius.circular(borderRadiusNone);
  static BorderRadius get borderRadiusXSValue =>
      BorderRadius.circular(borderRadiusXS);
  static BorderRadius get borderRadiusSMValue =>
      BorderRadius.circular(borderRadiusSM);
  static BorderRadius get borderRadiusMDValue =>
      BorderRadius.circular(borderRadiusMD);
  static BorderRadius get borderRadiusLGValue =>
      BorderRadius.circular(borderRadiusLG);
  static BorderRadius get borderRadiusXLValue =>
      BorderRadius.circular(borderRadiusXL);
  static BorderRadius get borderRadiusXXLValue =>
      BorderRadius.circular(borderRadiusXXL);
  static BorderRadius get borderRadiusFullValue =>
      BorderRadius.circular(borderRadiusFull);

  // ============================================================================
  // ELEVATION LEVELS (Shadows)
  // ============================================================================

  /// No elevation - 0dp
  static const double elevationLevel0 = 0.0;

  /// Subtle elevation - 1dp (raised slightly)
  static const double elevationLevel1 = 1.0;

  /// Light elevation - 2dp (cards, raised buttons)
  static const double elevationLevel2 = 2.0;

  /// Medium elevation - 4dp (FABs resting, cards on hover)
  static const double elevationLevel3 = 4.0;

  /// Elevated element - 6dp (app bars, menus)
  static const double elevationLevel4 = 6.0;

  /// High elevation - 8dp (FABs pressed, snackbars)
  static const double elevationLevel5 = 8.0;

  /// Very high elevation - 12dp (dialogs)
  static const double elevationLevel6 = 12.0;

  /// Extreme elevation - 16dp (navigation drawer)
  static const double elevationLevel7 = 16.0;

  /// Maximum elevation - 24dp (modal bottom sheet)
  static const double elevationLevel8 = 24.0;

  // ============================================================================
  // RESPONSIVE BREAKPOINTS
  // ============================================================================

  /// Mobile breakpoint - 600dp
  static const double breakpointMobile = 600.0;

  /// Tablet breakpoint - 1024dp
  static const double breakpointTablet = 1024.0;

  /// Desktop breakpoint - 1440dp
  static const double breakpointDesktop = 1440.0;

  /// Check if current width is mobile
  static bool isMobile(double width) => width < breakpointMobile;

  /// Check if current width is tablet
  static bool isTablet(double width) =>
      width >= breakpointMobile && width < breakpointTablet;

  /// Check if current width is desktop
  static bool isDesktop(double width) => width >= breakpointTablet;

  // ============================================================================
  // SCREEN MARGINS
  // ============================================================================

  /// Screen margin for mobile - 16dp
  static const double screenMarginMobile = 16.0;

  /// Screen margin for tablet - 24dp
  static const double screenMarginTablet = 24.0;

  /// Screen margin for desktop - 32dp
  static const double screenMarginDesktop = 32.0;

  /// Get responsive screen margin based on width
  static double getScreenMargin(double width) {
    if (isMobile(width)) return screenMarginMobile;
    if (isTablet(width)) return screenMarginTablet;
    return screenMarginDesktop;
  }

  // ============================================================================
  // CONTENT WIDTH
  // ============================================================================

  /// Maximum content width for desktop - 1200dp
  static const double maxContentWidth = 1200.0;

  /// Maximum width for dialogs - 560dp
  static const double maxDialogWidth = 560.0;

  /// Maximum width for forms - 480dp
  static const double maxFormWidth = 480.0;

  // ============================================================================
  // APP BAR DIMENSIONS
  // ============================================================================

  /// Standard app bar height - 56dp
  static const double appBarHeight = 56.0;

  /// Large app bar height - 64dp
  static const double appBarHeightLarge = 64.0;

  /// Bottom app bar height - 80dp
  static const double bottomAppBarHeight = 80.0;

  // ============================================================================
  // LIST ITEM DIMENSIONS
  // ============================================================================

  /// Single line list item height - 56dp
  static const double listItemHeightSingle = 56.0;

  /// Two line list item height - 72dp
  static const double listItemHeightTwo = 72.0;

  /// Three line list item height - 88dp
  static const double listItemHeightThree = 88.0;

  /// List item padding
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 8.0,
  );

  // ============================================================================
  // CHIP DIMENSIONS
  // ============================================================================

  /// Chip height - 32dp
  static const double chipHeight = 32.0;

  /// Chip padding
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(
    horizontal: 12.0,
    vertical: 6.0,
  );
}
