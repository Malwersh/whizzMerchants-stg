import 'delete_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design_system/design_system.dart';
import '../l10n/app_localizations.dart';
import '../utils/responsive_helper.dart';
import 'support_chat_screen.dart';
import '../services/api_service.dart';
import '../providers/business_provider.dart';
import '../providers/auth_provider_riverpod.dart';
import '../core/adaptive/adaptive_widgets.dart';

class AboutAppScreen extends ConsumerStatefulWidget {
  const AboutAppScreen({super.key});

  @override
  ConsumerState<AboutAppScreen> createState() => _AboutAppScreenState();
}

class _AboutAppScreenState extends ConsumerState<AboutAppScreen> {
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    return Container(
      margin: EdgeInsets.only(
        bottom: isMobile ? AppSpacing.md : 0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: AppSpacing.sm,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(
          isMobile ? AppSpacing.md : (isTablet ? AppSpacing.lg : AppSpacing.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(
                isMobile ? AppSpacing.xs : AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusSM),
              ),
              child: Icon(
                icon,
                color: color,
                size: ResponsiveHelper.getResponsiveIconSize(
                  context,
                  baseSize: 24,
                ),
              ),
            ),
            SizedBox(width: isMobile ? AppSpacing.md : AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                      fontSize: ResponsiveHelper.getResponsiveFontSize(
                        context,
                        16,
                      ),
                    ),
                  ),
                  SizedBox(height: GoldenRatio.xs),
                  Text(
                    content,
                    style: AppTypography.bodyMedium.copyWith(
                      color: const Color(0xFF1A1A1A)
                          .withValues(alpha: 0.7),
                      fontSize: ResponsiveHelper.getResponsiveFontSize(
                        context,
                        14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveInfoGrid(
    BuildContext context,
    AppLocalizations loc,
    ThemeData theme,
  ) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    final infoCards = [
      {
        'title': loc.aboutTitle,
        'content': loc.aboutDescription,
        'icon': Icons.info_outline_rounded,
        'color': theme.colorScheme.primary,
      },
      {
        'title': loc.features,
        'content': loc.featuresDescription,
        'icon': Icons.star_outline_rounded,
        'color': theme.colorScheme.secondary,
      },
      {
        'title': loc.contactUs,
        'content': loc.contactDescription,
        'icon': Icons.email_outlined,
        'color': WhizzColors.info,
      },
      {
        'title': loc.developer,
        'content': loc.developerInfo,
        'icon': Icons.code_rounded,
        'color': WhizzColors.success,
      },
    ];

    // Mobile: Stack vertically
    if (isMobile) {
      return Column(
        children: infoCards
            .map((card) => _buildInfoCard(
                  title: card['title'] as String,
                  content: card['content'] as String,
                  icon: card['icon'] as IconData,
                  color: card['color'] as Color,
                ))
            .toList(),
      );
    }

    // Tablet/Desktop: Grid layout
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            isTablet ? 2 : 2; // 2 columns for both tablet and desktop
        final spacing = ResponsiveHelper.getResponsivePadding(context);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: isTablet ? 1.3 : 1.5,
          ),
          itemCount: infoCards.length,
          itemBuilder: (context, index) {
            final card = infoCards[index];
            return _buildInfoCard(
              title: card['title'] as String,
              content: card['content'] as String,
              icon: card['icon'] as IconData,
              color: card['color'] as Color,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);

    return Scaffold(
      backgroundColor: WhizzColors.white,
      appBar: AppBar(
        title: Text(
          loc.aboutApp,
          style: AppTypography.headlineMedium.copyWith(
            color: const Color(0xFF1A1A1A),
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
          ),
        ),
        backgroundColor: WhizzColors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: const Color(0xFF1A1A1A),
            size: ResponsiveHelper.getResponsiveIconSize(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1200 : (isTablet ? 800 : double.infinity),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(
                  ResponsiveHelper.getResponsivePadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // App Logo/Icon
                  Container(
                    padding: EdgeInsets.all(
                      isMobile
                          ? AppSpacing.md
                          : (isTablet ? AppSpacing.lg : AppSpacing.xl),
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.borderRadiusXL),
                    ),
                    child: Icon(
                      Icons.store_rounded,
                      size: ResponsiveHelper.getResponsiveIconSize(context,
                          baseSize: 80),
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: isMobile ? AppSpacing.md : AppSpacing.lg),

                  // App Name
                  Text(
                    'WIZZ Business Manager',
                    style: AppTypography.displayMedium.copyWith(
                      color: const Color(0xFF1A1A1A),
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveHelper.getResponsiveFontSize(
                        context,
                        isMobile ? 24 : (isTablet ? 28 : 32),
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: GoldenRatio.xs),

                  // Version Info
                  Text(
                    '${loc.version} $_version (Build $_buildNumber)',
                    style: AppTypography.bodyMedium.copyWith(
                      color: Color(0xFF1A1A1A).withValues(alpha: 0.6),
                      fontSize:
                          ResponsiveHelper.getResponsiveFontSize(context, 14),
                    ),
                  ),
                  SizedBox(height: isMobile ? AppSpacing.lg : AppSpacing.xl),

                  // Info Cards - Responsive Grid
                  _buildResponsiveInfoGrid(context, loc, theme),

                  SizedBox(height: isMobile ? AppSpacing.lg : AppSpacing.xl),

                  // Quick actions row: Contact + Chat with Support
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: [
                      // Contact us button (navigates to email intent or placeholder if not implemented)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.email_outlined),
                        label: Text(loc.contactUs),
                        onPressed: () {
                          // Placeholder: implement contact-us flow if available
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(loc.contactUs)),
                          );
                        },
                      ),
                      // Chat with Support button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.support_agent_rounded),
                        label: const Text('Chat with Support'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SupportChatScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: isMobile ? AppSpacing.lg : AppSpacing.xl),

                  // Copyright
                  Text(
                    '© 2025 Whizz Ecosystem',
                    style: AppTypography.bodySmall.copyWith(
                      color: Color(0xFF1A1A1A).withValues(alpha: 0.5),
                      fontSize:
                          ResponsiveHelper.getResponsiveFontSize(context, 12),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: GoldenRatio.xs),
                  Text(
                    loc.allRightsReserved,
                    style: AppTypography.bodySmall.copyWith(
                      color: Color(0xFF1A1A1A).withValues(alpha: 0.5),
                      fontSize:
                          ResponsiveHelper.getResponsiveFontSize(context, 12),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Account Management - Delete Account
                  SizedBox(
                      height:
                          isMobile ? AppSpacing.xl * 2 : AppSpacing.xxl * 2),

                  // Simple text link for delete account
                  TextButton.icon(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    label: Text(
                      'Delete Account',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize:
                            ResponsiveHelper.getResponsiveFontSize(context, 13),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    onPressed: _showDeleteAccountSurvey,
                  ),
                  SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Survey reasons for deletion
  final List<Map<String, dynamic>> _deletionReasons = [
    {
      'title': 'Not using the service anymore',
      'icon': Icons.timer_off_outlined,
    },
    {
      'title': 'Too expensive',
      'icon': Icons.money_off_outlined,
    },
    {
      'title': 'Found a better alternative',
      'icon': Icons.compare_arrows_outlined,
    },
    {
      'title': 'Technical issues',
      'icon': Icons.bug_report_outlined,
    },
    {
      'title': 'Privacy concerns',
      'icon': Icons.privacy_tip_outlined,
    },
    {
      'title': 'Closing my business',
      'icon': Icons.store_outlined,
    },
    {
      'title': 'Other',
      'icon': Icons.help_outline,
    },
  ];

  void _showDeleteAccountSurvey() async {
    await openMerchantDeletion(context, ref.read(businessProvider).value?.id);
  }

  void _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: WhizzColors.error,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('Delete Account?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action cannot be undone. This will permanently delete:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildDeleteWarningItem('Your business profile'),
            _buildDeleteWarningItem('All your products and menu items'),
            _buildDeleteWarningItem('Order history'),
            _buildDeleteWarningItem('Business analytics and reports'),
            _buildDeleteWarningItem('All associated data'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: WhizzColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: WhizzColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action is permanent and cannot be reversed.',
                      style: TextStyle(
                        fontSize: 12,
                        color: WhizzColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: WhizzColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete My Account'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _confirmAndDeleteAccount();
    }
  }

  Widget _buildDeleteWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            Icons.close,
            size: 16,
            color: WhizzColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAndDeleteAccount() async {
    final businessAsyncValue = ref.read(businessProvider);
    final business = businessAsyncValue.value;

    if (business == null) {
      showAdaptiveSnackBar(
        context: context,
        message: 'Unable to delete account. Business data not found.',
        type: AdaptiveSnackBarType.error,
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AdaptiveLoadingIndicator(),
              const SizedBox(height: 16),
              const Text('Deleting your account...'),
              const SizedBox(height: 8),
              Text(
                'Please wait while we process your request.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Call API to delete account
      final apiService = ApiService();
      await apiService.deleteBusinessAccount(business.id);

      // Sign out user
      final authNotifier = ref.read(authProviderRiverpod.notifier);
      await authNotifier.signOut();

      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Navigate to auth screen
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/signin',
          (route) => false,
        );

        // Show success message
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            showAdaptiveSnackBar(
              context: context,
              message: 'Your account has been successfully deleted.',
              type: AdaptiveSnackBarType.success,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Show error message
        showAdaptiveSnackBar(
          context: context,
          message: 'Failed to delete account: ${e.toString()}',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }
}
