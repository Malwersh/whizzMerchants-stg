/// Design System - Spacing Constants
///
/// All spacing values follow an 8pt base unit system for consistency.
/// Use these constants instead of hardcoded values throughout the app.
///
/// Based on Material Design 3 spacing guidelines.
class AppSpacing {
  AppSpacing._(); // Private constructor to prevent instantiation

  // ============================================================================
  // CORE SPACING VALUES (8pt Grid System)
  // ============================================================================

  /// None - 0dp
  /// Use for: No spacing
  static const double none = 0.0;

  /// Extra extra small spacing - 4dp
  /// Use for: Very tight spacing, icon padding, chip padding
  static const double xxs = 4.0;

  /// Extra small spacing - 8dp
  /// Use for: Compact layouts, list item spacing, small gaps
  static const double xs = 8.0;

  /// Small spacing - 12dp
  /// Use for: Form field spacing, small sections
  static const double sm = 12.0;

  /// Medium spacing - 16dp (Base unit)
  /// Use for: Standard padding, general spacing, card content
  static const double md = 16.0;

  /// Large spacing - 24dp
  /// Use for: Section spacing, card padding, larger gaps
  static const double lg = 24.0;

  /// Extra large spacing - 32dp
  /// Use for: Major section breaks, screen padding
  static const double xl = 32.0;

  /// Extra extra large spacing - 48dp
  /// Use for: Large separations, hero spacing, major sections
  static const double xxl = 48.0;

  /// Extra extra extra large spacing - 64dp
  /// Use for: Maximum separations, feature spacing
  static const double xxxl = 64.0;

  // ============================================================================
  // SEMANTIC SPACING (Named by purpose)
  // ============================================================================

  /// Screen edge padding (horizontal)
  static const double screenPaddingHorizontal = md; // 16dp

  /// Screen edge padding (vertical)
  static const double screenPaddingVertical = lg; // 24dp

  /// Card padding
  static const double cardPadding = md; // 16dp

  /// Card spacing (between cards)
  static const double cardSpacing = xs; // 8dp

  /// List item padding (vertical)
  static const double listItemPaddingVertical = md; // 16dp

  /// List item padding (horizontal)
  static const double listItemPaddingHorizontal = md; // 16dp

  /// List item spacing (between items)
  static const double listItemSpacing = xs; // 8dp

  /// Section spacing (between major sections)
  static const double sectionSpacing = lg; // 24dp

  /// Form field spacing (between fields)
  static const double formFieldSpacing = md; // 16dp

  /// Button padding (horizontal)
  static const double buttonPaddingHorizontal = lg; // 24dp

  /// Button padding (vertical)
  static const double buttonPaddingVertical = sm; // 12dp

  /// Dialog padding
  static const double dialogPadding = lg; // 24dp

  /// Bottom sheet padding
  static const double bottomSheetPadding = lg; // 24dp

  /// App bar padding (horizontal)
  static const double appBarPaddingHorizontal = md; // 16dp

  /// Icon button padding
  static const double iconButtonPadding = xs; // 8dp

  /// Chip padding (horizontal)
  static const double chipPaddingHorizontal = sm; // 12dp

  /// Chip padding (vertical)
  static const double chipPaddingVertical = xxs; // 4dp

  /// Chip spacing (between chips)
  static const double chipSpacing = xs; // 8dp

  // ============================================================================
  // RESPONSIVE SPACING HELPERS
  // ============================================================================

  /// Get responsive horizontal padding based on screen width
  static double getResponsiveHorizontalPadding(double screenWidth) {
    if (screenWidth < 600) {
      return md; // 16dp for mobile
    } else if (screenWidth < 1024) {
      return lg; // 24dp for tablet
    } else {
      return xl; // 32dp for desktop
    }
  }

  /// Get responsive vertical padding based on screen height
  static double getResponsiveVerticalPadding(double screenHeight) {
    if (screenHeight < 600) {
      return md; // 16dp for small screens
    } else if (screenHeight < 900) {
      return lg; // 24dp for medium screens
    } else {
      return xl; // 32dp for large screens
    }
  }

  /// Get responsive card padding based on screen width
  static double getResponsiveCardPadding(double screenWidth) {
    if (screenWidth < 600) {
      return md; // 16dp for mobile
    } else {
      return lg; // 24dp for tablet/desktop
    }
  }
}
