import 'package:flutter/material.dart';
import '../core/theme/gradient_colors.dart';
import '../core/design_system/design_system.dart';
import '../widgets/instagram_style_card.dart';
import '../widgets/instagram_gradient_button.dart';

/// Showcase screen demonstrating Instagram-style design language
class InstagramDesignShowcase extends StatefulWidget {
  const InstagramDesignShowcase({super.key});

  @override
  State<InstagramDesignShowcase> createState() => _InstagramDesignShowcaseState();
}

class _InstagramDesignShowcaseState extends State<InstagramDesignShowcase> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: GradientColors.subtlePurple,
        ),
        child: CustomScrollView(
          slivers: [
            // App Bar with Instagram gradient
            SliverAppBar(
              expandedHeight: 200.0,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Instagram Design',
                  style: AppTypography.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: GradientColors.instagram,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(GoldenRatio.lg),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          child: const Icon(
                            Icons.palette,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Content
            SliverPadding(
              padding: EdgeInsets.all(GoldenRatio.lg),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Section: Gradient Cards
                  _buildSectionHeader('Gradient Cards'),
                  SizedBox(height: GoldenRatio.md),
                  
                  GradientCard(
                    gradientType: GradientType.purplePink,
                    child: _buildCardContent(
                      'Purple Pink',
                      'Modern vibrant gradient',
                      Icons.favorite,
                    ),
                  ),
                  SizedBox(height: GoldenRatio.md),

                  GradientCard(
                    gradientType: GradientType.sunset,
                    child: _buildCardContent(
                      'Sunset',
                      'Warm evening colors',
                      Icons.wb_sunny,
                    ),
                  ),
                  SizedBox(height: GoldenRatio.md),

                  GradientCard(
                    gradientType: GradientType.ocean,
                    child: _buildCardContent(
                      'Ocean',
                      'Cool water tones',
                      Icons.water,
                    ),
                  ),
                  SizedBox(height: GoldenRatio.md),

                  GradientCard(
                    gradientType: GradientType.fire,
                    child: _buildCardContent(
                      'Fire',
                      'Hot energetic vibes',
                      Icons.local_fire_department,
                    ),
                  ),

                  SizedBox(height: AppSpacing.xxl),

                  // Section: Buttons
                  _buildSectionHeader('Gradient Buttons'),
                  SizedBox(height: GoldenRatio.md),

                  InstagramGradientButton(
                    text: 'Purple Pink Button',
                    gradient: GradientColors.purplePink,
                    icon: Icons.touch_app,
                    onPressed: () => _showSnackbar('Purple Pink tapped'),
                  ),
                  SizedBox(height: GoldenRatio.md),

                  InstagramGradientButton(
                    text: 'Blue Purple Button',
                    gradient: GradientColors.bluePurple,
                    icon: Icons.thumb_up,
                    onPressed: () => _showSnackbar('Blue Purple tapped'),
                  ),
                  SizedBox(height: GoldenRatio.md),

                  InstagramGradientButton(
                    text: 'Orange Yellow Button',
                    gradient: GradientColors.orangeYellow,
                    icon: Icons.star,
                    onPressed: () => _showSnackbar('Orange Yellow tapped'),
                  ),
                  SizedBox(height: GoldenRatio.md),

                  InstagramOutlinedButton(
                    text: 'Outlined Button',
                    gradient: GradientColors.purplePink,
                    icon: Icons.favorite_border,
                    onPressed: () => _showSnackbar('Outlined button tapped'),
                  ),

                  SizedBox(height: AppSpacing.xxl),

                  // Section: Stats Cards
                  _buildSectionHeader('Stats Cards'),
                  SizedBox(height: GoldenRatio.md),

                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '1.2K',
                          'Orders',
                          Icons.shopping_bag,
                          GradientColors.purplePink,
                        ),
                      ),
                      SizedBox(width: GoldenRatio.md),
                      Expanded(
                        child: _buildStatCard(
                          '\$24.5K',
                          'Revenue',
                          Icons.attach_money,
                          GradientColors.greenTeal,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: GoldenRatio.md),

                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '4.8',
                          'Rating',
                          Icons.star,
                          GradientColors.orangeYellow,
                        ),
                      ),
                      SizedBox(width: GoldenRatio.md),
                      Expanded(
                        child: _buildStatCard(
                          '98%',
                          'Success',
                          Icons.check_circle,
                          GradientColors.ocean,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: AppSpacing.xxl),

                  // Section: Glass Morphism
                  _buildSectionHeader('Glass Morphism'),
                  SizedBox(height: GoldenRatio.md),

                  Container(
                    height: 200,
                    decoration: const BoxDecoration(
                      gradient: GradientColors.sunset,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: InstagramStyleCard(
                            enableGlassMorphism: true,
                            backgroundColor: Colors.transparent,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cloud, size: 48, color: Colors.white),
                                SizedBox(height: GoldenRatio.md),
                                Text(
                                  'Glass Morphism Effect',
                                  style: AppTypography.titleLarge.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: GoldenRatio.sm),
                                Text(
                                  'Modern translucent design',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: GoldenRatio.xxl),
                ]),
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
      style: AppTypography.headlineMedium.copyWith(
        fontWeight: FontWeight.bold,
        color: WhizzColors.textPrimary,
      ),
    );
  }

  Widget _buildCardContent(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(GoldenRatio.md),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(GoldenRatio.sm),
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
        SizedBox(width: GoldenRatio.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: GoldenRatio.xs),
              Text(
                subtitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Gradient gradient) {
    return InstagramStyleCard(
      gradient: gradient,
      padding: EdgeInsets.all(GoldenRatio.lg),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          SizedBox(height: GoldenRatio.sm),
          Text(
            value,
            style: AppTypography.headlineMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: GoldenRatio.xs),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.md),
        ),
      ),
    );
  }
}
