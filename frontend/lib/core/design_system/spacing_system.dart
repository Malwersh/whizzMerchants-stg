import 'package:flutter/material.dart';
import 'golden_ratio_constants.dart';

/// Spacing System
///
/// Provides consistent spacing utilities based on golden ratio proportions.
/// Includes padding, margin, and sizing utilities for consistent layouts.

class SpacingSystem {
  SpacingSystem._();

  // ══════════════════════════════════════════════════════════════════════════
  // EDGE INSETS - Standard spacing patterns
  // ══════════════════════════════════════════════════════════════════════════

  /// Extra small padding: 4px all around
  static const EdgeInsets allXs = EdgeInsets.all(GoldenRatio.xs);

  /// Small padding: 8px all around
  static const EdgeInsets allSm = EdgeInsets.all(GoldenRatio.sm);

  /// Medium padding: ~13px all around
  static const EdgeInsets allMd = EdgeInsets.all(GoldenRatio.md);

  /// Large padding: ~21px all around
  static const EdgeInsets allLg = EdgeInsets.all(GoldenRatio.lg);

  /// Extra large padding: ~34px all around
  static const EdgeInsets allXl = EdgeInsets.all(GoldenRatio.xl);

  /// Extra extra large padding: ~55px all around
  static const EdgeInsets allXxl = EdgeInsets.all(GoldenRatio.xxl);

  /// Extra extra extra large padding: ~89px all around
  static const EdgeInsets allXxxl = EdgeInsets.all(GoldenRatio.xxxl);

  // ══════════════════════════════════════════════════════════════════════════
  // INDIVIDUAL SPACING VALUES
  // ══════════════════════════════════════════════════════════════════════════

  /// Extra small spacing: 4px
  static const double xs = GoldenRatio.xs;

  /// Small spacing: 8px
  static const double sm = GoldenRatio.sm;

  /// Medium spacing: ~13px
  static const double md = GoldenRatio.md;

  /// Large spacing: ~21px
  static const double lg = GoldenRatio.lg;

  /// Extra large spacing: ~34px
  static const double xl = GoldenRatio.xl;

  /// Extra extra large spacing: ~55px
  static const double xxl = GoldenRatio.xxl;

  /// Extra extra extra large spacing: ~89px
  static const double xxxl = GoldenRatio.xxxl;

  /// Page content padding with extra large spacing
  static const EdgeInsets pageContent = EdgeInsets.all(GoldenRatio.xl);

  // ══════════════════════════════════════════════════════════════════════════
  // COMPONENT-SPECIFIC SPACING
  // ══════════════════════════════════════════════════════════════════════════

  /// Standard button padding
  static const EdgeInsets button = EdgeInsets.symmetric(
    horizontal: GoldenRatio.lg,
    vertical: GoldenRatio.md,
  );

  /// Standard card padding
  static const EdgeInsets card = EdgeInsets.all(GoldenRatio.lg);

  /// Standard input field padding
  static const EdgeInsets inputField = EdgeInsets.symmetric(
    horizontal: GoldenRatio.md,
    vertical: GoldenRatio.sm,
  );

  /// Page content padding
  static const EdgeInsets page = EdgeInsets.all(GoldenRatio.lg);

  /// Section spacing
  static const EdgeInsets section = EdgeInsets.symmetric(
    vertical: GoldenRatio.xl,
    horizontal: GoldenRatio.lg,
  );
}

/// Widget extensions for easy spacing
extension PaddingExtensions on Widget {
  /// Add padding using golden ratio spacing
  Widget paddingXs() => Padding(padding: SpacingSystem.allXs, child: this);
  Widget paddingSm() => Padding(padding: SpacingSystem.allSm, child: this);
  Widget paddingMd() => Padding(padding: SpacingSystem.allMd, child: this);
  Widget paddingLg() => Padding(padding: SpacingSystem.allLg, child: this);
  Widget paddingXl() => Padding(padding: SpacingSystem.allXl, child: this);
  Widget paddingXxl() => Padding(padding: SpacingSystem.allXxl, child: this);
  Widget paddingXxxl() => Padding(padding: SpacingSystem.allXxxl, child: this);

  /// Add custom padding
  Widget paddingAll(double value) => Padding(
        padding: EdgeInsets.all(value),
        child: this,
      );

  /// Add horizontal padding
  Widget paddingHorizontal(double value) => Padding(
        padding: EdgeInsets.symmetric(horizontal: value),
        child: this,
      );

  /// Add vertical padding
  Widget paddingVertical(double value) => Padding(
        padding: EdgeInsets.symmetric(vertical: value),
        child: this,
      );
}

/// Spacing widgets for layout
class SpacingWidgets {
  SpacingWidgets._();

  // Horizontal spacing
  static const Widget horizontalXs = SizedBox(width: GoldenRatio.xs);
  static const Widget horizontalSm = SizedBox(width: GoldenRatio.sm);
  static const Widget horizontalMd = SizedBox(width: GoldenRatio.md);
  static const Widget horizontalLg = SizedBox(width: GoldenRatio.lg);
  static const Widget horizontalXl = SizedBox(width: GoldenRatio.xl);
  static const Widget horizontalXxl = SizedBox(width: GoldenRatio.xxl);
  static const Widget horizontalXxxl = SizedBox(width: GoldenRatio.xxxl);

  // Vertical spacing
  static const Widget verticalXs = SizedBox(height: GoldenRatio.xs);
  static const Widget verticalSm = SizedBox(height: GoldenRatio.sm);
  static const Widget verticalMd = SizedBox(height: GoldenRatio.md);
  static const Widget verticalLg = SizedBox(height: GoldenRatio.lg);
  static const Widget verticalXl = SizedBox(height: GoldenRatio.xl);
  static const Widget verticalXxl = SizedBox(height: GoldenRatio.xxl);
  static const Widget verticalXxxl = SizedBox(height: GoldenRatio.xxxl);
}
