import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './account_settings_page.dart';
import './pos_settings_page.dart';
import './working_hours_settings_screen.dart';
import './about_app_screen.dart';
import './auth/auth_screen.dart';
import '../widgets/language_settings_bottom_drawer.dart';
import '../widgets/location_settings_full_bottom_drawer.dart';
import '../widgets/gps_settings_bottom_drawer.dart';
import '../l10n/app_localizations.dart';
import '../models/business.dart';
import '../models/order.dart';
import '../services/app_auth_service.dart';
import '../services/app_state.dart';
import '../providers/session_provider.dart';
import '../providers/business_provider.dart';
import '../providers/auth_provider_riverpod.dart';
import '../core/design_system/design_system.dart';
import '../core/adaptive/adaptive_widgets.dart';
import '../core/exceptions/auth_exceptions.dart';
import '../core/utils/app_logger.dart';

class ProfileSettingsPage extends ConsumerStatefulWidget {
  final Business business;
  final List<Order> orders;
  final Function(int)? onNavigateToPage;
  final Function(String, OrderStatus)? onOrderUpdated;

  const ProfileSettingsPage({
    super.key,
    required this.business,
    required this.orders,
    this.onNavigateToPage,
    this.onOrderUpdated,
  });

  @override
  _ProfileSettingsPageState createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends ConsumerState<ProfileSettingsPage> {
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      // Load user data from AppAuthService
      final userResponse = await AppAuthService.getCurrentUser();
      if (userResponse != null && userResponse['success'] == true) {
        // User data loaded successfully
      }
    } on AuthTokenExpiredException catch (e) {
      AppLogger.error(
          '[ProfileSettings] Auth token expired loading user data: ${e.message}');
      if (mounted) {
        ref.read(sessionProvider.notifier).clearSession();
        showAdaptiveSnackBar(
          context: context,
          message: AppLocalizations.of(context)!.sessionExpiredPleaseLoginAgain,
          type: AdaptiveSnackBarType.error,
        );
      }
    } on UnauthorizedException catch (e) {
      AppLogger.error(
          '[ProfileSettings] Unauthorized loading user data: ${e.message}');
      if (mounted) {
        ref.read(sessionProvider.notifier).clearSession();
        showAdaptiveSnackBar(
          context: context,
          message: AppLocalizations.of(context)!.sessionExpiredPleaseLoginAgain,
          type: AdaptiveSnackBarType.error,
        );
      }
    } catch (e) {
      AppLogger.error('[ProfileSettings] Error loading user data: $e');
      if (mounted) {
        // Handle generic errors silently or show a user-friendly message
      }
    }
  }

















  Widget _buildModernSettingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: AppSpacing.sm,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSM),
                  ),
                  child: Icon(
                    icon,
                    color: color,
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
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      SizedBox(height: GoldenRatio.xs),
                      Text(
                        subtitle,
                        style: AppTypography.bodyMedium.copyWith(
                          color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSM),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: theme.colorScheme.secondary,
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.signOut),
        content: Text(loc.signOutConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(loc.signOut, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                AdaptiveLoadingIndicator(
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 12),
                Text(loc.signOut),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 5),
          ),
        );

        // CRITICAL FIX: Sign out from AppAuthService FIRST (clears tokens & session)
        await ref.read(authProviderRiverpod.notifier).signOut();
        
        // Clear all Riverpod providers to reset cached state
        ref.invalidate(sessionProvider);
        ref.invalidate(businessProvider);
        
        // Clear app state (online status, etc.)
        final appState = AppState();
        appState.logout();

        if (mounted) {
          // Hide loading snackbar
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          
          // Navigate to auth screen and clear navigation stack
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AuthScreen()),
            (route) => false,
          );
          
          // Show success message after navigation
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Logged out successfully'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          showAdaptiveSnackBar(
            context: context,
            message: 'Error during logout: $e',
            type: AdaptiveSnackBarType.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppSpacing.lg),
          children: [
              // Settings Cards with Modern Design
            _buildModernSettingsCard(
                icon: Icons.account_circle_rounded,
                title: loc.accountSettings,
                subtitle: loc.manageYourPersonalInformation,
              color: theme.colorScheme.secondary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AccountSettingsPage(business: widget.business),
                    ),
                  );
                },
              ),
            SizedBox(height: AppSpacing.sm),
            _buildModernSettingsCard(
              icon: Icons.language_rounded,
              title: loc.languageSettings,
              subtitle: loc.changeAppLanguagePreference,
              color: theme.colorScheme.secondary,
              onTap: () {
                LanguageSettingsBottomDrawer.show(context);
              },
            ),
            const SizedBox(height: 12),
              _buildModernSettingsCard(
                icon: Icons.point_of_sale_rounded,
                title: loc.posSettings,
                subtitle: loc.configurePointOfSaleIntegration,
              color: theme.colorScheme.secondary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PosSettingsPage(business: widget.business),
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
              _buildModernSettingsCard(
                icon: Icons.location_on_rounded,
                title: AppLocalizations.of(context)!.locationSettings,
                subtitle: loc.manageBusinessLocationAndGpsCoordinates,
              color: theme.colorScheme.primary,
                onTap: () {
                LocationSettingsFullBottomDrawer.show(
                  context: context,
                  business: widget.business,
                );
              },
            ),
            const SizedBox(height: 12),
            _buildModernSettingsCard(
              icon: Icons.gps_fixed_rounded,
              title: 'GPS Settings',
              subtitle: 'Manage GPS coordinates and location tracking',
              color: theme.colorScheme.secondary,
              onTap: () {
                GpsSettingsBottomDrawer.show(
                  context: context,
                  business: widget.business,
                );
              },
            ),
            const SizedBox(height: 12),
              _buildModernSettingsCard(
                icon: Icons.access_time_rounded,
                title: AppLocalizations.of(context)!.workingHoursSettings,
                subtitle: loc.setUpOpeningAndClosingHoursForYourBusiness,
              color: theme.colorScheme.secondary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          WorkingHoursSettingsScreen(business: widget.business),
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
            _buildModernSettingsCard(
              icon: Icons.info_outline_rounded,
              title: loc.aboutApp,
              subtitle: loc.appInformationAndVersion,
              color: WhizzColors.info,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AboutAppScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

              // Material 3 Logout Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _signOut,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Icon(
                            Icons.logout_rounded,
                          color: WhizzColors.secondary,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            loc.logout,
                          style: TextStyle(
                            color: WhizzColors.secondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
