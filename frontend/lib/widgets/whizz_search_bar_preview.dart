import 'package:flutter/material.dart';
import '../core/design_system/golden_ratio_constants.dart';
import '../core/design_system/typography_system.dart';
import '../core/theme/whizz_colors.dart';
import 'whizz_search_bar.dart';

/// WhizzSearchBarPreview - Example screen demonstrating search bar usage
///
/// This screen showcases various configurations of the WhizzSearchBar widget:
/// - Standard search bar with rounded corners
/// - Compact search bar for toolbars
/// - Disabled state
/// - Custom icons and colors
/// - Different border radius options
class WhizzSearchBarPreview extends StatefulWidget {
  const WhizzSearchBarPreview({super.key});

  @override
  State<WhizzSearchBarPreview> createState() => _WhizzSearchBarPreviewState();
}

class _WhizzSearchBarPreviewState extends State<WhizzSearchBarPreview> {
  final TextEditingController _standardController = TextEditingController();
  final TextEditingController _compactController = TextEditingController();
  final TextEditingController _customController = TextEditingController();
  final TextEditingController _disabledController =
      TextEditingController(text: 'Disabled search');

  String _searchResults = '';

  @override
  void dispose() {
    _standardController.dispose();
    _compactController.dispose();
    _customController.dispose();
    _disabledController.dispose();
    super.dispose();
  }

  void _handleSearch(String query) {
    setState(() {
      _searchResults =
          query.isEmpty ? 'No search query' : 'Searching for: "$query"';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WhizzColors.grey50,
      appBar: AppBar(
        title: Text(
          'Search Bar Examples',
          style: TypographySystem.titleLarge.copyWith(
            color: WhizzColors.white,
          ),
        ),
        backgroundColor: WhizzColors.secondary,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(GoldenRatio.spacing16),
        children: [
          // Standard Search Bar
          _buildSection(
            title: 'Standard Search Bar',
            description: 'Default rounded corners with yellow focus',
            child: WhizzSearchBar(
              controller: _standardController,
              hintText: 'Search products, orders, customers...',
              onChanged: _handleSearch,
              onSubmitted: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Search submitted: $value'),
                    backgroundColor: WhizzColors.primary,
                  ),
                );
              },
            ),
          ),

          SizedBox(height: GoldenRatio.spacing24),

          // Compact Search Bar
          _buildSection(
            title: 'Compact Search Bar',
            description: 'Smaller version for toolbars and app bars',
            child: WhizzSearchBarCompact(
              controller: _compactController,
              hintText: 'Quick search...',
              onChanged: _handleSearch,
            ),
          ),

          SizedBox(height: GoldenRatio.spacing24),

          // Custom Icon Search Bar
          _buildSection(
            title: 'Custom Icon & Color',
            description: 'Custom filter icon with blue focus color',
            child: WhizzSearchBar(
              controller: _customController,
              hintText: 'Filter by name, category...',
              prefixIcon: Icons.filter_list,
              focusColor: WhizzColors.secondary,
              onChanged: _handleSearch,
            ),
          ),

          SizedBox(height: GoldenRatio.spacing24),

          // Disabled Search Bar
          _buildSection(
            title: 'Disabled State',
            description: 'Greyed out and non-interactive',
            child: WhizzSearchBar(
              controller: _disabledController,
              hintText: 'Search disabled',
              enabled: false,
            ),
          ),

          SizedBox(height: GoldenRatio.spacing24),

          // Extra Rounded Search Bar
          _buildSection(
            title: 'Extra Rounded Corners',
            description: 'Pill-shaped search bar with maximum border radius',
            child: WhizzSearchBar(
              controller: TextEditingController(),
              hintText: 'Pill-shaped search...',
              borderRadius: BorderRadius.circular(100),
              onChanged: _handleSearch,
            ),
          ),

          SizedBox(height: GoldenRatio.spacing24),

          // Search Results Display
          if (_searchResults.isNotEmpty)
            Container(
              padding: EdgeInsets.all(GoldenRatio.spacing16),
              decoration: BoxDecoration(
                color: WhizzColors.white,
                borderRadius: BorderRadius.circular(GoldenRatio.spacing12),
                border: Border.all(
                  color: WhizzColors.primary,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: const Color(0xFF00296B),
                    size: GoldenRatio.md,
                  ),
                  SizedBox(width: GoldenRatio.spacing8),
                  Expanded(
                    child: Text(
                      _searchResults,
                      style: TypographySystem.bodyLarge.copyWith(
                        color: WhizzColors.grey900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: GoldenRatio.spacing24),

          // Usage Documentation
          _buildDocumentation(),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TypographySystem.titleMedium.copyWith(
            color: WhizzColors.grey900,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: GoldenRatio.spacing4),
        Text(
          description,
          style: TypographySystem.bodySmall.copyWith(
            color: WhizzColors.grey600,
          ),
        ),
        SizedBox(height: GoldenRatio.spacing12),
        child,
      ],
    );
  }

  Widget _buildDocumentation() {
    return Container(
      padding: EdgeInsets.all(GoldenRatio.spacing16),
      decoration: BoxDecoration(
        color: WhizzColors.grey100,
        borderRadius: BorderRadius.circular(GoldenRatio.spacing12),
        border: Border.all(
          color: WhizzColors.grey300,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: WhizzColors.secondary,
                size: GoldenRatio.sm,
              ),
              SizedBox(width: GoldenRatio.spacing8),
              Text(
                'Usage Guide',
                style: TypographySystem.titleSmall.copyWith(
                  color: WhizzColors.grey900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: GoldenRatio.spacing12),
          Text(
            'Key Features:\n'
            '• Rounded corners using golden ratio spacing\n'
            '• Yellow brand color on focus\n'
            '• Auto-appearing clear button\n'
            '• Haptic feedback support\n'
            '• Customizable icons and colors\n'
            '• Material 3 design system integration\n'
            '• Compact variant for toolbars\n',
            style: TypographySystem.bodySmall.copyWith(
              color: WhizzColors.grey700,
              height: 1.6,
            ),
          ),
          SizedBox(height: GoldenRatio.spacing8),
          Text(
            'Import:\n'
            'import \'package:whizzmerchants/widgets/whizz_search_bar.dart\';',
            style: TypographySystem.bodySmall.copyWith(
              color: WhizzColors.grey700,
              fontFamily: 'monospace',
              backgroundColor: WhizzColors.grey200,
            ),
          ),
        ],
      ),
    );
  }
}
