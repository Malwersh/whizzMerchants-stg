import 'package:flutter/material.dart';

/// Instagram-inspired vibrant gradient colors
/// Clean design language with multicolor gradients for whizzMerchants
class GradientColors {
  GradientColors._();

  // ══════════════════════════════════════════════════════════════════════════
  // INSTAGRAM-STYLE MULTICOLOR GRADIENTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Classic Instagram gradient (Purple → Pink → Orange → Yellow)
  static const LinearGradient instagram = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF833AB4), // Purple
      Color(0xFFC13584), // Pink
      Color(0xFFE1306C), // Hot Pink
      Color(0xFFFD1D1D), // Red
      Color(0xFFF56040), // Orange
      Color(0xFFFCAF45), // Yellow
    ],
    stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
  );

  /// Purple to Pink gradient
  static const LinearGradient purplePink = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF8B5CF6), // Purple
      Color(0xFFEC4899), // Pink
    ],
  );

  /// Pink to Orange gradient
  static const LinearGradient pinkOrange = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEC4899), // Pink
      Color(0xFFF97316), // Orange
    ],
  );

  /// Orange to Yellow gradient
  static const LinearGradient orangeYellow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF97316), // Orange
      Color(0xFFFBBF24), // Yellow
    ],
  );

  /// Blue to Purple gradient
  static const LinearGradient bluePurple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF3B82F6), // Blue
      Color(0xFF8B5CF6), // Purple
    ],
  );

  /// Green to Teal gradient
  static const LinearGradient greenTeal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF10B981), // Green
      Color(0xFF06B6D4), // Teal
    ],
  );

  /// Sunset gradient (Pink → Orange → Yellow)
  static const LinearGradient sunset = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF6B9D), // Light Pink
      Color(0xFFFFA06B), // Light Orange
      Color(0xFFFFE66D), // Light Yellow
    ],
  );

  /// Ocean gradient (Blue → Teal → Green)
  static const LinearGradient ocean = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4F46E5), // Indigo
      Color(0xFF06B6D4), // Teal
      Color(0xFF10B981), // Green
    ],
  );

  /// Fire gradient (Red → Orange → Yellow)
  static const LinearGradient fire = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEF4444), // Red
      Color(0xFFF97316), // Orange
      Color(0xFFFBBF24), // Yellow
    ],
  );

  /// Purple Dream gradient
  static const LinearGradient purpleDream = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF667EEA), // Light Purple
      Color(0xFF764BA2), // Dark Purple
    ],
  );

  /// Peach gradient
  static const LinearGradient peach = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFD746C), // Coral
      Color(0xFFFF9068), // Peach
    ],
  );

  /// Mint gradient
  static const LinearGradient mint = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF43E97B), // Mint
      Color(0xFF38F9D7), // Light Green
    ],
  );

  /// Rose gradient
  static const LinearGradient rose = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF093FB), // Light Purple
      Color(0xFFF5576C), // Rose
    ],
  );

  /// Sky gradient
  static const LinearGradient sky = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4FACFE), // Light Blue
      Color(0xFF00F2FE), // Cyan
    ],
  );

  // ══════════════════════════════════════════════════════════════════════════
  // SUBTLE GRADIENTS FOR BACKGROUNDS
  // ══════════════════════════════════════════════════════════════════════════

  /// Subtle purple background
  static LinearGradient get subtlePurple => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      const Color(0xFF8B5CF6).withValues(alpha: 0.1),
      const Color(0xFFEC4899).withValues(alpha: 0.05),
    ],
  );

  /// Subtle blue background
  static LinearGradient get subtleBlue => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      const Color(0xFF3B82F6).withValues(alpha: 0.1),
      const Color(0xFF8B5CF6).withValues(alpha: 0.05),
    ],
  );

  /// Subtle green background
  static LinearGradient get subtleGreen => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      const Color(0xFF10B981).withValues(alpha: 0.1),
      const Color(0xFF06B6D4).withValues(alpha: 0.05),
    ],
  );

  /// Subtle orange background
  static LinearGradient get subtleOrange => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      const Color(0xFFF97316).withValues(alpha: 0.1),
      const Color(0xFFFBBF24).withValues(alpha: 0.05),
    ],
  );

  // ══════════════════════════════════════════════════════════════════════════
  // RADIAL GRADIENTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Radial Instagram gradient
  static const RadialGradient instagramRadial = RadialGradient(
    center: Alignment.topLeft,
    radius: 1.5,
    colors: [
      Color(0xFF833AB4), // Purple
      Color(0xFFC13584), // Pink
      Color(0xFFFD1D1D), // Red
      Color(0xFFF56040), // Orange
    ],
    stops: [0.0, 0.3, 0.6, 1.0],
  );

  /// Radial purple glow
  static const RadialGradient purpleGlow = RadialGradient(
    center: Alignment.center,
    radius: 1.0,
    colors: [
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Colors.transparent,
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // ══════════════════════════════════════════════════════════════════════════
  // SHIMMER GRADIENTS FOR LOADING STATES
  // ══════════════════════════════════════════════════════════════════════════

  /// Shimmer gradient for loading states
  static const LinearGradient shimmer = LinearGradient(
    begin: Alignment(-1.0, -0.5),
    end: Alignment(2.0, 0.5),
    colors: [
      Color(0xFFEBEBF4),
      Color(0xFFF4F4F6),
      Color(0xFFEBEBF4),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // ══════════════════════════════════════════════════════════════════════════
  // GLASS MORPHISM GRADIENTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Glass morphism overlay
  static LinearGradient get glassMorphism => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: 0.2),
      Colors.white.withValues(alpha: 0.1),
    ],
  );

  /// Dark glass morphism
  static LinearGradient get darkGlassMorphism => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.black.withValues(alpha: 0.2),
      Colors.black.withValues(alpha: 0.1),
    ],
  );
}
