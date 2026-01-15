import 'package:flutter/material.dart';
// import '../design_system.dart';  // Temporarily disabled
// import '../spacing_system.dart';
import '../golden_ratio_constants.dart';
import '../typography_system.dart';
import '../../theme/whizz_colors.dart';

/// Card Themes
///
/// Provides consistent card styling throughout the app using
/// Material Design 3 patterns with golden ratio proportions.

class CardThemes {
  CardThemes._();

  // ══════════════════════════════════════════════════════════════════════════
  // BASIC CARD STYLES
  // ══════════════════════════════════════════════════════════════════════════

  /// Standard card with basic elevation
  static Widget standardCard({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsets? padding,
  }) {
    return Card(
      elevation: GoldenRatio.xs,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GoldenRatio.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GoldenRatio.md),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(GoldenRatio.lg),
          child: child,
        ),
      ),
    );
  }

  /// Elevated card with higher elevation
  static Widget elevatedCard({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsets? padding,
  }) {
    return Card(
      elevation: GoldenRatio.sm,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GoldenRatio.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GoldenRatio.md),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(GoldenRatio.lg),
          child: child,
        ),
      ),
    );
  }

  /// Outlined card with border instead of elevation
  static Widget outlinedCard({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsets? padding,
    Color? borderColor,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GoldenRatio.md),
        side: BorderSide(
          color: borderColor ?? Colors.grey.shade300,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GoldenRatio.md),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(GoldenRatio.lg),
          child: child,
        ),
      ),
    );
  }

  /// Filled card with background color
  static Widget filledCard({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsets? padding,
    Color? backgroundColor,
  }) {
    return Card(
      elevation: 0,
      color: backgroundColor ?? WhizzColors.primary.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GoldenRatio.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GoldenRatio.md),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(GoldenRatio.lg),
          child: child,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERACTIVE CARD WIDGETS
  // ══════════════════════════════════════════════════════════════════════════

  /// Action card with primary button styling
  static Widget actionCard({
    required Widget child,
    required VoidCallback onTap,
    EdgeInsets? padding,
    bool isSelected = false,
  }) {
    return Card(
      elevation: isSelected ? GoldenRatio.sm : GoldenRatio.xs,
      color: isSelected ? WhizzColors.primary.withValues(alpha: 0.1) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GoldenRatio.md),
        side: isSelected
            ? BorderSide(color: WhizzColors.primary, width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GoldenRatio.md),
        splashColor: WhizzColors.primary.withValues(alpha: 0.2),
        highlightColor: WhizzColors.primary.withValues(alpha: 0.1),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(GoldenRatio.lg),
          child: child,
        ),
      ),
    );
  }

  /// Expandable card that can show/hide content
  static Widget expandableCard({
    required Widget title,
    required Widget content,
    bool isExpanded = false,
    required ValueChanged<bool> onExpansionChanged,
    EdgeInsets? padding,
  }) {
    return Card(
      elevation: GoldenRatio.xs,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GoldenRatio.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: title,
        initiallyExpanded: isExpanded,
        onExpansionChanged: onExpansionChanged,
        childrenPadding: padding ?? const EdgeInsets.all(GoldenRatio.lg),
        tilePadding: padding ?? const EdgeInsets.all(GoldenRatio.lg),
        children: [content],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SPECIALIZED CARD WIDGETS
  // ══════════════════════════════════════════════════════════════════════════

  /// Status card with colored indicator
  static Widget statusCard({
    required Widget child,
    required Color statusColor,
    VoidCallback? onTap,
    EdgeInsets? padding,
  }) {
    return Card(
      elevation: GoldenRatio.xs,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GoldenRatio.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: statusColor,
              width: GoldenRatio.xs,
            ),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GoldenRatio.md),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(GoldenRatio.lg),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Metric card for displaying key statistics
  static Widget metricCard({
    required String title,
    required String value,
    String? subtitle,
    IconData? icon,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return standardCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: GoldenRatio.lg,
                  color: iconColor ?? WhizzColors.primary,
                ),
                const SizedBox(width: GoldenRatio.sm),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TypographySystem.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: GoldenRatio.sm),
          Text(
            value,
            style: TypographySystem.headlineMedium.copyWith(
              color: WhizzColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: GoldenRatio.xs),
            Text(
              subtitle,
              style: TypographySystem.bodySmall.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Image card with optional overlay content
  static Widget imageCard({
    required String imageUrl,
    Widget? overlay,
    VoidCallback? onTap,
    double aspectRatio = 16 / 9,
  }) {
    return Card(
      elevation: GoldenRatio.xs,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GoldenRatio.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.broken_image,
                      size: GoldenRatio.xl,
                      color: Colors.grey.shade400,
                    ),
                  );
                },
              ),
              if (overlay != null)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(GoldenRatio.lg),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: overlay,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Feature card with icon, title, and description
  static Widget featureCard({
    required IconData icon,
    required String title,
    required String description,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    return standardCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(GoldenRatio.sm),
            decoration: BoxDecoration(
              color: (iconColor ?? WhizzColors.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(GoldenRatio.sm),
            ),
            child: Icon(
              icon,
              size: GoldenRatio.lg,
              color: iconColor ?? WhizzColors.primary,
            ),
          ),
          const SizedBox(height: GoldenRatio.md),
          Text(
            title,
            style: TypographySystem.titleMedium,
          ),
          const SizedBox(height: GoldenRatio.sm),
          Text(
            description,
            style: TypographySystem.bodyMedium.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// Info card with blue accent styling
  static Widget infoCard({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsets? padding,
  }) {
    return Card(
      elevation: GoldenRatio.xs,
      color: const Color(0xFF0288D1)
          .withValues(alpha: 0.05), // Light blue background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GoldenRatio.md),
        side: const BorderSide(
          color: Color(0xFF0288D1), // Blue border
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GoldenRatio.md),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(GoldenRatio.lg),
          child: child,
        ),
      ),
    );
  }
}
