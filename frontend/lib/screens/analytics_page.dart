import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../utils/responsive_helper.dart';
import '../models/business.dart';
import '../models/order.dart';
import '../core/design_system/design_system.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  final Business? business;
  final List<Order>? orders;
  final VoidCallback? onNavigateToOrders;
  final Function(String, OrderStatus)? onOrderUpdated;

  const AnalyticsPage({
    super.key,
    this.business,
    this.orders,
    this.onNavigateToOrders,
    this.onOrderUpdated,
  });

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: WhizzColors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(ResponsiveHelper.isMobile(context)
              ? AppSpacing.sm
              : AppSpacing.md),
          child: Column(
            children: [
              // Stats Cards
              _buildStatsGrid(context, loc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, AppLocalizations loc) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      padding: EdgeInsets.all(
          isMobile ? AppSpacing.sm : AppSpacing.lg),
      decoration: BoxDecoration(
        color: WhizzColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXL),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: WhizzColors.elevation(2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount;
          double childAspectRatio;

          if (constraints.maxWidth < 600) {
            // Mobile: 2 columns
            crossAxisCount = 2;
            childAspectRatio = 1.0;
          } else if (constraints.maxWidth < 900) {
            // Tablet: 2 columns
            crossAxisCount = 2;
            childAspectRatio = 1.3;
          } else {
            // Desktop: 4 columns
            crossAxisCount = 4;
            childAspectRatio = 1.1;
          }
          
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            mainAxisSpacing:
                isMobile ? AppSpacing.sm : AppSpacing.lg,
            crossAxisSpacing:
                isMobile ? AppSpacing.sm : AppSpacing.lg,
            children: [
              _buildStatCard(
                title: loc.totalOrders,
                value: '1,234',
                icon: Icons.shopping_cart_rounded,
              ),
              _buildStatCard(
                title: loc.revenueLabel,
                value: '\$12,345',
                icon: Icons.attach_money_rounded,
              ),
              _buildStatCard(
                title: loc.activeProducts,
                value: '89',
                icon: Icons.inventory_2_rounded,
              ),
              _buildStatCard(
                title: loc.customers,
                value: '567',
                icon: Icons.people_rounded,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        decoration: BoxDecoration(
          color: WhizzColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXL),
          border: Border.all(
            color:
                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: WhizzColors.elevation(2),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Handle analytics card tap if needed
            },
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXL),
            child: Container(
              padding: EdgeInsets.all(AppSpacing.md),
              child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 120;
                final iconSize =
                    isSmall
                      ? AppDimensions.iconSizeMD
                      : AppDimensions.iconSizeLG;
                final spacing =
                    isSmall ? AppSpacing.xs : AppSpacing.sm;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                        child: Container(
                        padding: EdgeInsets.all(isSmall
                            ? AppSpacing.xs : AppSpacing.sm),
                        decoration: BoxDecoration(
                            color: WhizzColors.grey100,
                          borderRadius:
                              BorderRadius.circular(
                                AppDimensions.borderRadiusLG),
                        ),
                        child: Icon(
                          icon,
                          size: iconSize,
                            color: WhizzColors.secondary,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                            style: AppTypography.headlineSmall.copyWith(
                              color: WhizzColors.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: isSmall ? 18 : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                      SizedBox(height: AppSpacing.xxs),
                    Flexible(
                      child: Text(
                        title,
                          style: AppTypography.bodyMedium.copyWith(
                            color: WhizzColors.secondary,
                          fontWeight: FontWeight.w500,
                          fontSize: isSmall ? 12 : null,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      ),
    );
  }


}
