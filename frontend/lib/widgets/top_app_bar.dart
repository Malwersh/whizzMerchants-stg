import '../screens/merchant_wallet_accounts_screen.dart';
import '../screens/merchant_notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../core/theme/whizz_colors.dart';
import '../l10n/app_localizations.dart';

/// TopAppBar with integrated online/offline toggle
/// This replaces the hamburger menu with a direct toggle
class TopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? businessId;
  final bool isOnline;
  final Future<void> Function(bool) onToggleStatus;
  final VoidCallback? onReturnOrder;
  final Function(int)? onNavigate;
  final bool showToggle;
  final bool isLoading;

  const TopAppBar({
    super.key,
    required this.title,
    this.businessId,
    required this.isOnline,
    required this.onToggleStatus,
    this.onReturnOrder,
    this.onNavigate,
    this.showToggle = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isIOS = theme.platform == TargetPlatform.iOS;

    return AppBar(
      title: Text(
        title.isEmpty ? 'Wizz Business' : title,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: WhizzColors.secondary,
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: WhizzColors.secondary,
      elevation: 0,
      centerTitle: true,
      toolbarHeight: 58,
      automaticallyImplyLeading: false, // Remove back button
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: Column(children: [
          if (isLoading) const LinearProgressIndicator(minHeight:2),
          SizedBox(height:60,child:SingleChildScrollView(scrollDirection:Axis.horizontal,
            child:Row(mainAxisAlignment:MainAxisAlignment.center,children: [
        if (businessId != null && businessId!.isNotEmpty)
          IconButton(tooltip:'الإشعارات',icon:const Icon(Icons.notifications_none_rounded,color:WhizzColors.secondary),
            onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>MerchantNotificationsScreen(businessId:businessId!)))),
        IconButton(
            tooltip: 'محافظ المطاعم',
            icon: const Icon(Icons.account_balance_wallet_outlined,
                color: WhizzColors.secondary),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MerchantWalletAccountsScreen()))),
        if (showToggle) ...[
          // Online/Offline Status Toggle
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status indicator
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isOnline
                        ? theme.colorScheme.primary
                        : theme.colorScheme.secondary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isOnline
                                ? theme.colorScheme.primary
                                : theme.colorScheme.secondary)
                            .withValues(alpha: 0.5),
                        blurRadius: 3,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Status text
                Text(
                  isOnline ? loc.online : loc.offline,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(width: 10),

                // Toggle Switch
                Transform.scale(
                  scale: 0.85, // Make switch smaller to fit
                  child: isIOS
                      ? CupertinoSwitch(
                          value: isOnline,
                          onChanged: _handleToggle,
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: theme.colorScheme.secondary,
                        )
                      : Switch.adaptive(
                          value: isOnline,
                          onChanged: _handleToggle,
                          activeColor: theme.colorScheme.primary,
                          activeTrackColor: theme.colorScheme.secondary
                              .withValues(alpha: 0.5),
                          inactiveTrackColor:
                              theme.colorScheme.primary.withValues(alpha: 0.3),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                ),
              ],
            ),
          ),
        ],

        // Menu button for return order (if needed)
        if (onReturnOrder != null)
          IconButton(
            onPressed: () => _showQuickMenu(context),
            icon: Icon(
              Icons.more_vert,
              color: WhizzColors.secondary,
              size: 24,
            ),
            tooltip: loc.menu,
          ),
      ]))),
        ]),
      ),
    );
  }

  void _handleToggle(bool? value) async {
    if (value != null) {
      try {
        await onToggleStatus(value);
      } catch (e) {
        // Error handling is done in the callback
        debugPrint('Toggle error: $e');
      }
    }
  }

  void _showQuickMenu(BuildContext context) {
    if (onReturnOrder == null) return;

    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  Icon(Icons.assignment_return, color: WhizzColors.primary),
              title: Text(loc.returnOrder),
              onTap: () {
                Navigator.pop(context);
                onReturnOrder!();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize =>
      const Size.fromHeight(120);
}
