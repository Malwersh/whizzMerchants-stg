// filepath: /Users/ghaythallaheebi/order-receiver-app-2/frontend/lib/screens/design_system_example_screen.dart

import 'package:flutter/material.dart';
import '../core/design_system/design_system.dart';

class DesignSystemExampleScreen extends StatelessWidget {
  const DesignSystemExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Design System Examples',
          style: AppTypography.headlineMedium,
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(GoldenRatio.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Typography Examples
            _buildSectionHeader('Typography'),
            const SizedBox(height: GoldenRatio.md),

            Text('Headline Large', style: AppTypography.headlineLarge),
            const SizedBox(height: GoldenRatio.sm),

            Text('Headline Medium', style: AppTypography.headlineMedium),
            const SizedBox(height: GoldenRatio.sm),

            Text('Headline Small', style: AppTypography.headlineSmall),
            const SizedBox(height: GoldenRatio.sm),

            Text('Body Large', style: AppTypography.bodyLarge),
            const SizedBox(height: GoldenRatio.sm),

            Text('Body Medium', style: AppTypography.bodyMedium),
            const SizedBox(height: GoldenRatio.sm),

            Text('Body Small', style: AppTypography.bodySmall),

            const SizedBox(height: AppSpacing.xxl),

            // Spacing Examples
            _buildSectionHeader('Spacing Examples'),
            const SizedBox(height: GoldenRatio.md),

            Container(
              padding: const EdgeInsets.all(GoldenRatio.xs),
              margin: const EdgeInsets.only(bottom: GoldenRatio.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSM),
              ),
              child: Text(
                'Extra Small Padding (${GoldenRatio.xs}px)',
                style: AppTypography.labelMedium,
              ),
            ),

            Container(
              padding: const EdgeInsets.all(GoldenRatio.sm),
              margin: const EdgeInsets.only(bottom: GoldenRatio.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSM),
              ),
              child: Text(
                'Small Padding (${GoldenRatio.sm}px)',
                style: AppTypography.labelMedium,
              ),
            ),

            Container(
              padding: const EdgeInsets.all(GoldenRatio.md),
              margin: const EdgeInsets.only(bottom: GoldenRatio.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
              ),
              child: Text(
                'Medium Padding (${GoldenRatio.md}px)',
                style: AppTypography.labelMedium,
              ),
            ),

            Container(
              padding: const EdgeInsets.all(GoldenRatio.lg),
              margin: const EdgeInsets.only(bottom: GoldenRatio.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
              ),
              child: Text(
                'Large Padding (${GoldenRatio.lg}px)',
                style: AppTypography.labelMedium,
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Button Examples
            _buildSectionHeader('Button Examples'),
            const SizedBox(height: GoldenRatio.md),

            Wrap(
              spacing: GoldenRatio.sm,
              runSpacing: GoldenRatio.sm,
              children: [
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Elevated Button'),
                ),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Outlined Button'),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Text Button'),
                ),
                FilledButton(
                  onPressed: () {},
                  child: const Text('Filled Button'),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Card Examples
            _buildSectionHeader('Card Examples'),
            const SizedBox(height: GoldenRatio.md),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(GoldenRatio.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Card Title',
                      style: AppTypography.headlineSmall,
                    ),
                    const SizedBox(height: GoldenRatio.sm),
                    Text(
                      'This is an example card using the design system spacing and typography.',
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: GoldenRatio.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {},
                          child: const Text('Action'),
                        ),
                        const SizedBox(width: GoldenRatio.sm),
                        ElevatedButton(
                          onPressed: () {},
                          child: const Text('Primary'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Golden Ratio Information
            _buildSectionHeader('Golden Ratio Constants'),
            const SizedBox(height: GoldenRatio.md),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(GoldenRatio.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Golden Ratio Values',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: GoldenRatio.sm),
                    _buildConstantRow('φ (phi)', GoldenRatio.phi.toString()),
                    _buildConstantRow(
                        'φ⁻¹ (phi inverse)', GoldenRatio.phiInverse.toString()),
                    const SizedBox(height: GoldenRatio.sm),
                    Text(
                      'Spacing Values',
                      style: AppTypography.titleSmall,
                    ),
                    const SizedBox(height: GoldenRatio.xs),
                    _buildConstantRow('XS', '${GoldenRatio.xs}px'),
                    _buildConstantRow('SM', '${GoldenRatio.sm}px'),
                    _buildConstantRow('MD', '${GoldenRatio.md}px'),
                    _buildConstantRow('LG', '${GoldenRatio.lg}px'),
                    _buildConstantRow('XL', '${AppSpacing.xxl}px'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTypography.headlineMedium,
    );
  }

  Widget _buildConstantRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMedium),
          Text(value, style: AppTypography.labelMedium),
        ],
      ),
    );
  }
}
