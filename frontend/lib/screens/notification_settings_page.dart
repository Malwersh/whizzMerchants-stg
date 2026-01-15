import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../core/design_system/design_system.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _newOrderNotifications = true;
  bool _orderStatusNotifications = true;
  bool _paymentNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _pushNotifications = prefs.getBool('notif_push') ?? true;
        _emailNotifications = prefs.getBool('notif_email') ?? true;
        _smsNotifications = prefs.getBool('notif_sms') ?? false;
        _newOrderNotifications = prefs.getBool('notif_new_order') ?? true;
        _orderStatusNotifications = prefs.getBool('notif_order_status') ?? true;
        _paymentNotifications = prefs.getBool('notif_payment') ?? true;
      });
    } catch (e) {
      // Handle error appropriately
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: WhizzColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: WhizzColors.secondary,
        foregroundColor: WhizzColors.white,
        elevation: 0,
        title: Text(
          loc.notificationSettings,
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: WhizzColors.white,
          ),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => _saveSettings(),
            style: FilledButton.styleFrom(
              backgroundColor: WhizzColors.textSecondary,
              foregroundColor: WhizzColors.onSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
              ),
            ),
            icon: const Icon(Icons.save_rounded),
            label: Text(loc.save),
          ),
          SizedBox(width: AppSpacing.md),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Delivery Methods Section
                _buildNotificationSection(
                loc.deliveryMethods,
                  Icons.send,
                WhizzColors.secondary,
                  [
                    _buildModernSwitchTile(
                    loc.pushNotifications,
                    loc.receiveNotificationsOnYourDevice,
                      _pushNotifications,
                      (value) => setState(() => _pushNotifications = value),
                      Icons.notifications,
                    WhizzColors.secondary,
                    ),
                    _buildModernSwitchTile(
                    loc.emailNotifications,
                    loc.receiveNotificationsViaEmail,
                      _emailNotifications,
                      (value) => setState(() => _emailNotifications = value),
                      Icons.email,
                    WhizzColors.textSecondary,
                    ),
                    _buildModernSwitchTile(
                    loc.smsNotifications,
                    loc.receiveNotificationsViaSMS,
                      _smsNotifications,
                      (value) => setState(() => _smsNotifications = value),
                      Icons.sms,
                    WhizzColors.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Order Notifications Section
                _buildNotificationSection(
                loc.orderNotifications,
                  Icons.shopping_cart,
                WhizzColors.textSecondary,
                  [
                    _buildModernSwitchTile(
                    loc.newOrders,
                    loc.getNotifiedWhenNewOrdersArrive,
                      _newOrderNotifications,
                      (value) => setState(() => _newOrderNotifications = value),
                      Icons.add_shopping_cart,
                    WhizzColors.secondary,
                    ),
                    _buildModernSwitchTile(
                    loc.orderStatusUpdates,
                    loc.getNotifiedWhenOrderStatusChanges,
                      _orderStatusNotifications,
                      (value) =>
                          setState(() => _orderStatusNotifications = value),
                      Icons.update,
                    WhizzColors.textSecondary,
                    ),
                    _buildModernSwitchTile(
                    loc.paymentNotifications,
                    loc.getNotifiedAboutPaymentUpdates,
                      _paymentNotifications,
                      (value) => setState(() => _paymentNotifications = value),
                      Icons.payment,
                    WhizzColors.secondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
      ),
    );
  }

  Widget _buildNotificationSection(
      String title, IconData icon, Color iconColor, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: WhizzColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXL),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: AppSpacing.lg,
            offset: Offset(0, GoldenRatio.sm),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: WhizzColors.grey50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppDimensions.borderRadiusXL),
                topRight: Radius.circular(AppDimensions.borderRadiusXL),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: WhizzColors.black,
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
                  ),
                  child: Icon(
                    icon,
                    color: WhizzColors.white,
                    size: AppSpacing.lg,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: WhizzColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSwitchTile(String title, String subtitle, bool value,
      ValueChanged<bool> onChanged, IconData icon, Color iconColor) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(GoldenRatio.sm),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(GoldenRatio.sm),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: AppSpacing.lg,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: WhizzColors.textPrimary,
                  ),
                ),
                SizedBox(height: GoldenRatio.xs),
                Text(
                  subtitle,
                  style: AppTypography.bodyMedium.copyWith(
                    color: WhizzColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: iconColor,
            activeTrackColor: iconColor.withValues(alpha: 0.3),
            inactiveTrackColor: WhizzColors.grey50,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_push', _pushNotifications);
      await prefs.setBool('notif_email', _emailNotifications);
      await prefs.setBool('notif_sms', _smsNotifications);
      await prefs.setBool('notif_new_order', _newOrderNotifications);
      await prefs.setBool('notif_order_status', _orderStatusNotifications);
      await prefs.setBool('notif_payment', _paymentNotifications);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: WhizzColors.textSecondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.black87,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.settingsSavedSuccessfully,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: WhizzColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.error_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!
                        .failedToSaveSettings(e.toString()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: WhizzColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}
