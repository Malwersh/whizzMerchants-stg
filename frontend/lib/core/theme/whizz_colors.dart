import 'package:flutter/material.dart';

/// WhizzColors - Official 3-Color Branding System
///
/// BRAND COLORS (60-10-30 Rule):
/// 1. WHITE (#FFFFFF)     - 60% coverage (backgrounds, space)
/// 2. PRIMARY (#FDC500)   - 10% coverage (CTAs, highlights)
/// 3. SECONDARY (#00296B) - 30% coverage (text, icons, structure)
///
/// All other colors are UTILITY ONLY (greys, semantic colors)
class WhizzColors {
  // ============================================================================
  // 🎨 OFFICIAL BRAND COLORS (THE ONLY 3 YOU NEED)
  // ============================================================================

  /// ⬜ WHITE SPACE - 60% coverage
  /// Use for: Backgrounds, surfaces, cards, dialogs, app bars
  /// This is the DOMINANT color - clean, modern, minimalist
  static const Color white = Color(0xFFFFFFFF);

  /// 🟡 PRIMARY (Brand Yellow) - 10% coverage
  /// Hex: #FDC500 | RGB: (253, 197, 0)
  /// Use for: CTAs, highlights, focus states, brand identity, badges
  /// Use sparingly for maximum impact - this draws the eye!
  static const Color primary = Color(0xFFFDC500);

  /// 🔵 SECONDARY (Brand Blue) - 30% coverage
  /// Hex: #00296B | RGB: (0, 41, 107)
  /// Use for: Text, icons, borders, structure, navigation, links
  /// This provides hierarchy and readability
  static const Color secondary = Color(0xFF00296B);

  // ============================================================================
  // 🔧 UTILITY GREYS (Use ONLY when brand colors don't work)
  // ============================================================================
  
  /// ⚠️ Use these ONLY for disabled states, subtle dividers, or when
  /// the brand secondary color (#00296B) is too strong

  /// Subtle background - Use when white needs slight differentiation
  static const Color grey50 = Color(0xFFFAFAFA);

  /// Light divider - Use for very subtle separations
  static const Color grey200 = Color(0xFFEEEEEE);

  /// Disabled state - Use for inactive elements only
  static const Color grey400 = Color(0xFFBDBDBD);

  /// Secondary text alternative - Use when blue is too strong
  /// ⚠️ Prefer secondary (#00296B) for primary text
  static const Color grey600 = Color(0xFF757575);

  // ============================================================================
  // 🎯 SEMANTIC COLORS (Use ONLY for alerts and status)
  // ============================================================================

  /// ✅ Success state - Green (use for success messages only)
  static const Color success = Color(0xFF10B981);

  /// ⚠️ Warning state - Orange (use for warnings only)
  static const Color warning = Color(0xFFF59E0B);

  /// ❌ Error state - Red (use for errors only)
  static const Color error = Color(0xFFD32F2F);

  /// ℹ️ Info state - Blue (use for info messages only)
  static const Color info = Color(0xFF3B82F6);

  // ============================================================================
  // 📦 ORDER STATUS COLORS (Functional use only)
  // ============================================================================

  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusConfirmed = Color(0xFFFDC500); // Uses primary
  static const Color statusPreparing = Color(0xFF8B5CF6);
  static const Color statusReady = Color(0xFF06B6D4);
  static const Color statusDelivered = Color(0xFF10B981);
  static const Color statusCancelled = Color(0xFFEF4444);
  static const Color statusReturned = Color(0xFFEC4899);
  static const Color statusExpired = Color(0xFF757575); // grey600

  // ============================================================================
  // 🎨 SEMANTIC ALIASES (Map to brand colors)
  // ============================================================================

  /// Primary text color - Uses SECONDARY brand color
  static const Color textPrimary = secondary; // #00296B

  /// Secondary text color - Uses grey for subtle text
  static const Color textSecondary = grey600; // #757575

  /// Text on dark backgrounds - Uses WHITE
  static const Color textOnDark = white; // #FFFFFF

  /// Primary border color - SECONDARY with 10% opacity
  static Color get borderPrimary => secondary.withValues(alpha: 0.1);

  /// Divider color - Light grey for subtle divisions
  static const Color divider = grey200;

  // ============================================================================
  // 🛠️ UTILITY ALIASES (Map to brand colors for backwards compatibility)
  // ============================================================================

  /// Background primary - Maps to WHITE (60% rule)
  static const Color backgroundPrimary = white;

  /// Border - Maps to borderPrimary
  static Color get border => borderPrimary;

  /// Border light - Maps to even lighter border
  static Color get borderLight => secondary.withValues(alpha: 0.05);

  /// Container colors - Light tints for semantic colors (use sparingly!)
  static Color get successContainer => success.withValues(alpha: 0.1);
  static Color get warningContainer => warning.withValues(alpha: 0.1);
  static Color get errorContainer => error.withValues(alpha: 0.1);
  static Color get infoContainer => info.withValues(alpha: 0.1);

  /// Shadow colors - Based on secondary with low opacity
  static Color get shadow => secondary.withValues(alpha: 0.1);
  static Color get shadowMedium => secondary.withValues(alpha: 0.15);
  static Color get shadowDark => secondary.withValues(alpha: 0.2);

  /// Missing grey shades - Map to available greys
  static const Color grey100 = grey50; // Map to lightest available
  static const Color grey300 = grey200; // Map to light grey
  static const Color grey500 = grey400; // Map to medium grey
  static const Color grey700 = grey600; // Map to dark grey
  static const Color grey800 = grey600; // Map to dark grey
  static const Color grey900 = secondary; // Map to brand secondary (darkest)

  /// Black - Maps to secondary (our darkest brand color)
  static const Color black = secondary;

  /// Light variants for theme support
  static Color get primaryLight => primary.withValues(alpha: 0.8);
  static Color get secondaryLight => const Color(0xFF4A90E2); // Lighter blue
  static Color get primaryDark => const Color(0xFFE5B000); // Darker yellow
  
  /// Additional semantic colors for backward compatibility
  static const Color onPrimary = white; // Text on primary color
  static const Color onSecondary = white; // Text on secondary color
  static const Color onSurface = secondary; // Text on surface (white)
  static const Color onError = white; // Text on error color
  static const Color surface = white; // Surface color (same as white)
  static const Color primaryContainer = primary; // Container using primary
  static const Color secondaryContainer =
      secondary; // Container using secondary
  static const Color surfaceVariant = grey50; // Slight variant of surface
  static const Color onSurfaceVariant = grey600; // Text on surface variant
  static const Color backgroundVariant =
      grey50; // Background variant (same as grey50)
  static const Color chipText =
      secondary; // Chip text color (same as secondary)
  static const Color chipIconSelected = primary; // Selected chip icon color
  static const Color surfaceContainer = grey50; // Surface container color

  // ============================================================================
  // 🚫 DEPRECATED LEGACY COLORS (DO NOT USE - kept for backwards compatibility)
  // ============================================================================

  /// ❌ DEPRECATED: Use 'primary' instead
  @Deprecated('Use WhizzColors.primary instead')
  static const Color brandYellow = Color(0xFFFDC500);

  /// ❌ DEPRECATED: Use 'primary' instead
  @Deprecated('Use WhizzColors.primary instead')
  static const Color brandYellowAlt = Color(0xFFFFD500);

  /// ❌ DEPRECATED: Use 'secondary' instead
  @Deprecated('Use WhizzColors.secondary instead')
  static const Color brandBluePrimary = Color(0xFF00509D);

  /// ❌ DEPRECATED: Use 'secondary' instead
  @Deprecated('Use WhizzColors.secondary instead')
  static const Color brandBlueMedium = Color(0xFF003F88);

  /// ❌ DEPRECATED: Use 'secondary' instead
  @Deprecated('Use WhizzColors.secondary instead')
  static const Color brandBlueDark = Color(0xFF00296B);

  // ============================================================================
  // 🛠️ HELPER METHODS
  // ============================================================================

  /// Get appropriate text color for a given background
  /// Returns secondary (blue) for light backgrounds, white for dark backgrounds
  static Color getTextColorForBackground(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5 ? secondary : white;
  }

  /// Check if a color is light
  static bool isLight(Color color) => color.computeLuminance() > 0.5;

  /// Check if a color is dark
  static bool isDark(Color color) => color.computeLuminance() <= 0.5;

  /// Get order status color based on status string
  static Color getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return statusPending;
      case 'confirmed':
        return statusConfirmed;
      case 'preparing':
        return statusPreparing;
      case 'ready':
        return statusReady;
      case 'delivered':
        return statusDelivered;
      case 'cancelled':
        return statusCancelled;
      case 'returned':
        return statusReturned;
      case 'expired':
        return statusExpired;
      default:
        return grey600;
    }
  }

  /// Get elevation shadow based on Material Design elevation levels (0-24)
  static List<BoxShadow> elevation(int level) {
    if (level <= 0) return [];

    final double blur = level * 2.0;
    final double offset = level * 0.5;
    final double opacity = (level * 0.02).clamp(0.05, 0.3);

    return [
      BoxShadow(
        color: secondary.withValues(alpha: opacity),
        blurRadius: blur,
        offset: Offset(0, offset),
        spreadRadius: 0,
      ),
    ];
  }
}

// ============================================================================
// 📖 USAGE GUIDE
// ============================================================================
//
// 60-10-30 RULE FOR PERFECT BALANCE:
//
// 1. WHITE (60%):
//    ✅ Scaffold backgrounds
//    ✅ Card surfaces
//    ✅ Dialog backgrounds
//    ✅ App bars
//    ✅ All empty space
//    Example: Scaffold(backgroundColor: WhizzColors.white)
//
// 2. PRIMARY YELLOW (10%):
//    ✅ Primary buttons
//    ✅ FAB (Floating Action Button)
//    ✅ Focus indicators
//    ✅ Important badges
//    ✅ CTAs (Call To Action)
//    Example: ElevatedButton(style: ElevatedButton.styleFrom(
//               backgroundColor: WhizzColors.primary))
//
// 3. SECONDARY BLUE (30%):
//    ✅ All text (headers, body, labels)
//    ✅ All icons
//    ✅ Navigation elements
//    ✅ Borders (with 10% opacity)
//    ✅ Links and tappable text
//    Example: Text('Hello', style: TextStyle(color: WhizzColors.secondary))
//
// 4. GREYS (<5%):
//    ⚠️  Disabled states only
//    ⚠️  Very subtle dividers
//    ⚠️  When blue is too strong
//    Example: Divider(color: WhizzColors.divider)
//
// 5. SEMANTIC COLORS (<5%):
//    🚨 Success/Error/Warning messages ONLY
//    🚨 Status indicators
//    Example: SnackBar with WhizzColors.error
//
// ============================================================================
