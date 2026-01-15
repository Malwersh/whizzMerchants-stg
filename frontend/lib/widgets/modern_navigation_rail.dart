import 'package:flutter/material.dart';
import '../core/theme/whizz_colors.dart';
import 'package:whizz_merchants/l10n/app_localizations.dart';
// Removed unused design system imports flagged by analyzer
// import '../core/design_system/golden_ratio_constants.dart';
// import '../core/design_system/typography_system.dart';

class ModernNavigationRail extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onNavigate;
  final bool isOnline;
  // Removed onToggleStatus - no toggle functionality needed

  const ModernNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.onNavigate,
    required this.isOnline,
    // Removed onToggleStatus parameter
  });

  @override
  State<ModernNavigationRail> createState() => _ModernNavigationRailState();
}

class _ModernNavigationRailState extends State<ModernNavigationRail>
    with TickerProviderStateMixin {
  late AnimationController _statusAnimationController;
  late Animation<double> _statusPulseAnimation;

  @override
  void initState() {
    super.initState();
    _statusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _statusPulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _statusAnimationController,
      curve: Curves.easeInOut,
    ));

    // Start pulsing animation for online status
    if (widget.isOnline) {
      _statusAnimationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ModernNavigationRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOnline != widget.isOnline) {
      if (widget.isOnline) {
        _statusAnimationController.repeat(reverse: true);
      } else {
        _statusAnimationController.stop();
        _statusAnimationController.reset();
      }
    }
  }

  @override
  void dispose() {
    _statusAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with status
          _buildHeader(context, localizations, colorScheme),

          // Navigation items
          Expanded(
            child: _buildNavigationItems(context, localizations, colorScheme),
          ),

          // Footer with additional info
          _buildFooter(context, localizations, colorScheme),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations localizations,
      ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00C1E8).withValues(alpha: 0.1),
            const Color(0xFF3399FF).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App branding
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C1E8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  color: const Color(0xFF00C1E8),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.appTitle,
                      style: TextStyle(
                        color: const Color(0xFF00C1E8),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      localizations.dashboard,
                      style: TextStyle(
                        color: WhizzColors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Status indicator
          _buildStatusIndicator(context, localizations, colorScheme),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context,
      AppLocalizations localizations, ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _statusPulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isOnline ? _statusPulseAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isOnline
                  ? const Color(0xFF00C1E8).withValues(alpha: 0.1)
                  : WhizzColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isOnline
                    ? const Color(0xFF00C1E8).withValues(alpha: 0.3)
                    : WhizzColors.warning.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color:
                      widget.isOnline ? WhizzColors.info : WhizzColors.warning,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isOnline
                            ? localizations.online
                            : localizations.offline,
                        style: TextStyle(
                          color: widget.isOnline
                              ? const Color(0xFF00C1E8)
                              : WhizzColors.warning,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        widget.isOnline
                            ? localizations.readyToReceiveOrders
                            : localizations.ordersArePaused,
                        style: TextStyle(
                          color: WhizzColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: widget.isOnline,
                  // Toggle locked: disable interactions to prevent websocket status updates
                  onChanged: null,
                  activeColor: const Color(0xFF00C1E8),
                  inactiveTrackColor: WhizzColors.warning,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationItems(BuildContext context,
      AppLocalizations localizations, ColorScheme colorScheme) {
    final navigationItems = [
      NavigationItem(
        icon: Icons.shopping_bag_rounded,
        selectedIcon: Icons.shopping_bag,
        label: localizations.orders,
        description: localizations.viewAndManageOrders,
      ),
      NavigationItem(
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2_rounded,
        label: localizations.items,
        description: localizations.menuItemsAndCategories,
      ),
      NavigationItem(
        icon: Icons.analytics_outlined,
        selectedIcon: Icons.analytics_rounded,
        label: localizations.analytics,
        description: localizations.businessInsights,
      ),
      NavigationItem(
        icon: Icons.local_offer_outlined,
        selectedIcon: Icons.local_offer_rounded,
        label: localizations.discounts,
        description: localizations.offersAndPromotions,
      ),
      NavigationItem(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings_rounded,
        label: localizations.settings,
        description: localizations.appConfiguration,
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: navigationItems.length,
      itemBuilder: (context, index) {
        final item = navigationItems[index];
        final isSelected = widget.selectedIndex == index;

        return _buildNavigationTile(
          context: context,
          item: item,
          isSelected: isSelected,
          onTap: () => widget.onNavigate(index),
          colorScheme: colorScheme,
        );
      },
    );
  }

  Widget _buildNavigationTile({
    required BuildContext context,
    required NavigationItem item,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00C1E8).withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF00C1E8).withValues(alpha: 0.3)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Icon with animation
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isSelected ? item.selectedIcon : item.icon,
                    key: ValueKey(isSelected),
                    color: isSelected
                        ? WhizzColors.primary
                        : WhizzColors.onSurfaceVariant,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected
                              ? WhizzColors.primary
                              : WhizzColors.onSurface,
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          style: TextStyle(
                            color: WhizzColors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Selected indicator
                if (isSelected)
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C1E8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, AppLocalizations localizations,
      ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00C1E8).withValues(alpha: 0.05),
        borderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.business_rounded,
                color: WhizzColors.onSurfaceVariant,
                size: 14,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  localizations.businessDashboardVersion,
                  style: TextStyle(
                    color: WhizzColors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: const Color(0xFF00C1E8).withValues(alpha: 0.6),
                size: 12,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  localizations.modernMaterialDesign,
                  style: TextStyle(
                    color: WhizzColors.textSecondary,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String description;

  const NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.description = '',
  });
}
