import 'package:flutter/material.dart';
import 'package:whizz_merchants/core/design_system/design_system.dart';

/// Example screen demonstrating the Design System
///
/// This file shows how to use the new design system components
/// in a real-world scenario. Copy these patterns for your own screens!
class DesignSystemExampleScreen extends StatelessWidget {
  const DesignSystemExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WhizzColors.backgroundPrimary,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Example 1: Typography
              _buildTypographyExample(),
              SizedBox(height: AppSpacing.xl),

              // Example 2: Spacing
              _buildSpacingExample(),
              SizedBox(height: AppSpacing.xl),

              // Example 3: Cards
              _buildCardExample(),
              SizedBox(height: AppSpacing.xl),

              // Example 4: Buttons
              _buildButtonsExample(),
              SizedBox(height: AppSpacing.xl),

              // Example 5: Responsive Layout
              _buildResponsiveExample(context),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Design System Examples',
        style: AppTypography.titleLarge.copyWith(
          color: WhizzColors.white,
        ),
      ),
      backgroundColor: WhizzColors.secondary,
      elevation: AppDimensions.elevationLevel2,
    );
  }

  Widget _buildTypographyExample() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Typography Scale',
          style: AppTypography.headlineMedium.copyWith(
            color: WhizzColors.textPrimary,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        _buildTypographyItem('Display Large', AppTypography.displayLarge),
        _buildTypographyItem('Headline Medium', AppTypography.headlineMedium),
        _buildTypographyItem('Title Medium', AppTypography.titleMedium),
        _buildTypographyItem('Body Medium', AppTypography.bodyMedium),
        _buildTypographyItem('Label Large', AppTypography.labelLarge),
      ],
    );
  }

  Widget _buildTypographyItem(String label, TextStyle style) {
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: WhizzColors.textSecondary,
            ),
          ),
          Text('The quick brown fox', style: style),
        ],
      ),
    );
  }

  Widget _buildSpacingExample() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Spacing Scale (8pt Grid)',
          style: AppTypography.headlineMedium.copyWith(
            color: WhizzColors.textPrimary,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        _buildSpacingItem('xxs', AppSpacing.xxs),
        _buildSpacingItem('xs', AppSpacing.xs),
        _buildSpacingItem('sm', AppSpacing.sm),
        _buildSpacingItem('md (base)', AppSpacing.md),
        _buildSpacingItem('lg', AppSpacing.lg),
        _buildSpacingItem('xl', AppSpacing.xl),
      ],
    );
  }

  Widget _buildSpacingItem(String label, double size) {
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: WhizzColors.textSecondary,
              ),
            ),
          ),
          Container(
            width: size,
            height: AppSpacing.md,
            color: WhizzColors.primary,
          ),
          SizedBox(width: AppSpacing.xs),
          Text(
            '${size.toInt()}dp',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildCardExample() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cards with Proper Spacing',
          style: AppTypography.headlineMedium.copyWith(
            color: WhizzColors.textPrimary,
          ),
        ),
        SizedBox(height: AppSpacing.sm),

        // Example Card 1: Standard Product Card
        Container(
          padding: EdgeInsets.all(AppSpacing.md),
          margin: EdgeInsets.only(bottom: AppSpacing.xs),
          decoration: BoxDecoration(
            color: WhizzColors.white,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
            border: Border.all(color: WhizzColors.borderPrimary),
            boxShadow: [
              BoxShadow(
                blurRadius: AppDimensions.elevationLevel2,
                color: WhizzColors.black.withValues(alpha: 0.05),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: WhizzColors.grey200,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.borderRadiusSM,
                      ),
                    ),
                    child: Icon(
                      Icons.image,
                      color: WhizzColors.grey400,
                      size: AppDimensions.iconSizeLG,
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Name',
                          style: AppTypography.titleMedium.copyWith(
                            color: WhizzColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Product category',
                          style: AppTypography.bodySmall.copyWith(
                            color: WhizzColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'This is a sample product description using the design system.',
                style: AppTypography.bodyMedium.copyWith(
                  color: WhizzColors.textPrimary,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$24.99',
                    style: AppTypography.titleLarge.copyWith(
                      color: WhizzColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: AppDimensions.iconSizeSM,
                    color: WhizzColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildButtonsExample() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Buttons (48dp Touch Targets)',
          style: AppTypography.headlineMedium.copyWith(
            color: WhizzColors.textPrimary,
          ),
        ),
        SizedBox(height: AppSpacing.sm),

        // Large Button
        SizedBox(
          height: AppDimensions.buttonHeightLarge,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: WhizzColors.primary,
              foregroundColor: WhizzColors.black,
              padding: AppDimensions.buttonPaddingLarge,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppDimensions.borderRadiusSM,
                ),
              ),
              elevation: AppDimensions.elevationLevel2,
            ),
            child: Text(
              'Primary Button',
              style: AppTypography.labelLarge,
            ),
          ),
        ),

        SizedBox(height: AppSpacing.sm),

        // Outlined Button
        SizedBox(
          height: AppDimensions.buttonHeightLarge,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: WhizzColors.secondary,
              padding: AppDimensions.buttonPaddingLarge,
              side: BorderSide(color: WhizzColors.borderPrimary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppDimensions.borderRadiusSM,
                ),
              ),
            ),
            child: Text(
              'Secondary Button',
              style: AppTypography.labelLarge,
            ),
          ),
        ),

        SizedBox(height: AppSpacing.sm),

        // Icon Button
        Row(
          children: [
            Container(
              width: AppDimensions.touchTargetRecommended,
              height: AppDimensions.touchTargetRecommended,
              decoration: BoxDecoration(
                color: WhizzColors.grey100,
                borderRadius: BorderRadius.circular(
                  AppDimensions.borderRadiusSM,
                ),
              ),
              child: IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.favorite,
                  size: AppDimensions.iconSizeMD,
                  color: WhizzColors.error,
                ),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Container(
              width: AppDimensions.touchTargetRecommended,
              height: AppDimensions.touchTargetRecommended,
              decoration: BoxDecoration(
                color: WhizzColors.grey100,
                borderRadius: BorderRadius.circular(
                  AppDimensions.borderRadiusSM,
                ),
              ),
              child: IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.share,
                  size: AppDimensions.iconSizeMD,
                  color: WhizzColors.secondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResponsiveExample(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = AppDimensions.isMobile(constraints.maxWidth);
        final isTablet = AppDimensions.isTablet(constraints.maxWidth);

        final deviceType = isMobile
            ? 'Mobile'
            : isTablet
                ? 'Tablet'
                : 'Desktop';
        final padding =
            AppSpacing.getResponsiveHorizontalPadding(constraints.maxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Responsive Layout',
              style: AppTypography.headlineMedium.copyWith(
                color: WhizzColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: WhizzColors.infoContainer,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusMD),
                border: Border.all(color: WhizzColors.info.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device: $deviceType',
                    style: AppTypography.titleMedium.copyWith(
                      color: WhizzColors.info,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Screen Width: ${constraints.maxWidth.toInt()}dp',
                    style: AppTypography.bodyMedium.copyWith(
                      color: WhizzColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Responsive Padding: ${padding.toInt()}dp',
                    style: AppTypography.bodyMedium.copyWith(
                      color: WhizzColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'This padding automatically adjusts based on screen size!',
              style: AppTypography.bodySmall.copyWith(
                color: WhizzColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        );
      },
    );
  }
}
