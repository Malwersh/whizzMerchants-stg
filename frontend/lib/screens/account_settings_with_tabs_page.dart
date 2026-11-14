import 'delete_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/business.dart';
import '../l10n/app_localizations.dart';
import '../services/app_auth_service.dart';
import '../providers/business_provider.dart';
import '../providers/session_provider.dart';
import '../core/utils/app_logger.dart';
import 'auth/auth_screen.dart';
import '../core/design_system/design_system.dart';
import '../core/adaptive/adaptive_widgets.dart';
import '../utils/responsive_helper.dart';

class AccountSettingsWithTabsPage extends ConsumerStatefulWidget {
  final Business business;

  const AccountSettingsWithTabsPage({super.key, required this.business});

  @override
  ConsumerState<AccountSettingsWithTabsPage> createState() =>
      _AccountSettingsWithTabsPageState();
}

class _AccountSettingsWithTabsPageState
    extends ConsumerState<AccountSettingsWithTabsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _businessNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _addressController;
  late TextEditingController _descriptionController;
  late TextEditingController _websiteController;
  late TextEditingController _phoneController;

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize controllers
    _businessNameController = TextEditingController();
    _ownerNameController = TextEditingController();
    _addressController = TextEditingController();
    _descriptionController = TextEditingController();
    _websiteController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized) {
      _isInitialized = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _validateAuthenticationAndInitialize();
        }
      });
    }
  }

  Future<void> _validateAuthenticationAndInitialize() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated) {
      _showAuthenticationRequiredDialog();
      return;
    }

    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated) {
      _showAuthenticationRequiredDialog();
    }
  }

  void _showAuthenticationRequiredDialog() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const Icon(
          Icons.security,
          color: Color(0xFF00C1E8),
          size: 48,
        ),
        title: Text(
          loc.userNotLoggedIn,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF001133),
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          loc.pleaseSignInToAccessAccountSettings,
          style: TextStyle(
            color: const Color(0xFF001133).withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => _navigateToLogin(),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF00C1E8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(loc.signIn),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const AuthScreen(),
      ),
      (route) => false,
    );
  }

  String _formatAddress(dynamic address) {
    if (address == null) return '';
    if (address is String) return address;
    if (address is Map<String, dynamic> && address.containsKey('S')) {
      return address['S']?.toString() ?? '';
    }
    if (address is Map<String, dynamic> && address.containsKey('M')) {
      return _formatAddress(address['M']);
    }
    final Map<String, dynamic> addrMap =
        Map<String, dynamic>.from(address as Map);
    String extract(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      if (v is Map<String, dynamic> && v.containsKey('S')) {
        return v['S']?.toString() ?? '';
      }
      if (v is Map<String, dynamic> && v.containsKey('M')) {
        final m = Map<String, dynamic>.from(v['M'] as Map);
        if (m.containsKey('S')) return m['S']?.toString() ?? '';
        return m.values
            .map((e) => extract(e))
            .where((s) => s.isNotEmpty)
            .join(' ');
      }
      return v.toString();
    }

    final components = <String>[
      extract(addrMap['home_address']),
      extract(addrMap['street']),
      extract(addrMap['neighborhood']),
      extract(addrMap['district']),
      extract(addrMap['city']),
      extract(addrMap['country']),
    ].where((c) => c.isNotEmpty).toList();
    return components.join(', ');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final businessAsyncValue = ref.watch(businessProvider);
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);

    return Scaffold(
      backgroundColor: WhizzColors.grey50,
      body: SafeArea(
        child: Column(
          children: [
            // Modern App Bar
            _buildModernAppBar(context, l10n),

            // Tab Bar
            Container(
              margin: EdgeInsets.fromLTRB(
                isMobile ? 12 : 16,
                8,
                isMobile ? 12 : 16,
                0,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: WhizzColors.secondary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: WhizzColors.primary,
                unselectedLabelColor: WhizzColors.grey600,
                indicatorColor: WhizzColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(
                    icon: Icon(Icons.account_circle_rounded),
                    text: l10n.accountSettings,
                  ),
                  Tab(
                    icon: Icon(Icons.delete_forever_rounded),
                    text: 'Delete Account',
                  ),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        isDesktop ? 1200 : (isTablet ? 900 : double.infinity),
                  ),
                  child: Container(
                    margin: EdgeInsets.fromLTRB(
                      isMobile ? 12 : 16,
                      0,
                      isMobile ? 12 : 16,
                      12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: WhizzColors.secondary.withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Profile Information Tab
                        _buildProfileTab(l10n, businessAsyncValue),

                        // Delete Account Tab
                        _buildDeleteAccountTab(l10n),
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

  Widget _buildModernAppBar(BuildContext context, AppLocalizations loc) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 20,
        12,
        isMobile ? 16 : 20,
        isMobile ? 16 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          AdaptiveBackButton(
            onPressed: () => Navigator.of(context).pop(),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.accountSettings,
                  style: TextStyle(
                    fontSize:
                        ResponsiveHelper.getResponsiveFontSize(context, 24),
                    fontWeight: FontWeight.bold,
                    color: WhizzColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(
      AppLocalizations l10n, AsyncValue<Business?> businessAsyncValue) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
      child: Consumer(
        builder: (context, ref, child) {
          final enhancedBusinessAsync = ref.watch(enhancedBusinessProvider);
          final businessAsyncValue = ref.watch(businessProvider);

          return enhancedBusinessAsync.when(
            data: (enhancedBusiness) {
              final business = enhancedBusiness ?? businessAsyncValue.value;
              if (business == null) {
                return _buildErrorMessage(
                    l10n, l10n.noBusinessFoundForThisAccount);
              }

              // Update controllers with fresh business data
              if (_businessNameController.text != business.name) {
                _businessNameController.text = business.name;
              }
              if (_ownerNameController.text != (business.ownerName ?? '')) {
                _ownerNameController.text = business.ownerName ?? '';
              }
              if (_addressController.text != _formatAddress(business.address)) {
                _addressController.text = _formatAddress(business.address);
              }
              if (_descriptionController.text != (business.description ?? '')) {
                _descriptionController.text = business.description ?? '';
              }
              if (_websiteController.text != (business.website ?? '')) {
                _websiteController.text = business.website ?? '';
              }
              if (_phoneController.text != (business.phone ?? '')) {
                _phoneController.text = business.phone ?? '';
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    l10n.accountSettings,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: WhizzColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your account and business information',
                    style: TextStyle(
                      fontSize: 14,
                      color: WhizzColors.grey600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'This is where the profile information will be displayed.',
                    style: TextStyle(
                      fontSize: 14,
                      color: WhizzColors.grey600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Business: ${business.name}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: WhizzColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Email: ${business.email}',
                    style: TextStyle(
                      fontSize: 14,
                      color: WhizzColors.grey700,
                    ),
                  ),
                ],
              );
            },
            loading: () => Center(
              child: AdaptiveLoadingIndicator(
                color: WhizzColors.primary,
                size: 32,
              ),
            ),
            error: (error, stack) => _buildErrorMessage(l10n, 'Error: $error'),
          );
        },
      ),
    );
  }

  Widget _buildDeleteAccountTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(ResponsiveHelper.getResponsivePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: Colors.red,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delete Account',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Permanently remove your account',
                      style: TextStyle(
                        fontSize: 14,
                        color: WhizzColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'What happens when you delete your account?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildWarningItem(
                    'Your business profile will be permanently deleted'),
                _buildWarningItem(
                    'All orders and order history will be removed'),
                _buildWarningItem('Products and menu items will be deleted'),
                _buildWarningItem('Customer reviews will be lost'),
                _buildWarningItem('All associated data will be erased'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This action cannot be undone. Please be certain.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Delete Account Process',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildStepItem(1, 'Click the "Delete Account" button below'),
          _buildStepItem(2, 'Confirm your decision in the dialog'),
          _buildStepItem(3, 'Enter your password to verify'),
          _buildStepItem(4, 'Your account will be permanently deleted'),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showDeleteAccountConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.delete_forever_rounded, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Delete My Account',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.close, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(int step, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: WhizzColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: WhizzColors.primary,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                '$step',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: WhizzColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(AppLocalizations l10n, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountConfirmation() async {
    await openMerchantDeletion(context, ref.read(businessProvider).value?.id);
  }

  Future<void> _showPasswordVerification() async {
    final passwordController = TextEditingController();
    bool isPasswordVisible = false;
    String? errorMessage;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.lock_rounded, color: WhizzColors.primary, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Verify Password',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your password to confirm account deletion',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: !isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        isPasswordVisible = !isPasswordVisible;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: errorMessage,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                passwordController.dispose();
                Navigator.of(context).pop(false);
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (passwordController.text.isEmpty) {
                  setState(() {
                    errorMessage = 'Please enter your password';
                  });
                } else {
                  Navigator.of(context).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteAccount(passwordController.text);
    }

    passwordController.dispose();
  }

  Future<void> _deleteAccount(String password) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdaptiveLoadingIndicator(
                  color: WhizzColors.primary,
                  size: 48,
                ),
                const SizedBox(height: 20),
                Text(
                  'Deleting account...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      await _clearAllData();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Navigate to login with a fresh ProviderScope to avoid provider errors
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => ProviderScope(
              child: const AuthScreen(),
            ),
          ),
          (route) => false,
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          // Note: Can't show snackbar here as context is no longer valid
          AppLogger.info('Account deleted successfully');
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        String errorMessage = 'Error deleting account';
        if (e.toString().contains('incorrect password') ||
            e.toString().contains('Invalid password')) {
          errorMessage = 'Incorrect password. Please try again.';
        } else if (e.toString().contains('Network')) {
          errorMessage = 'Network error. Please check your connection.';
        }

        showAdaptiveSnackBar(
          context: context,
          message: errorMessage,
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  Future<void> _clearAllData() async {
    try {
      // Clear Riverpod providers
      ref.invalidate(sessionProvider);
      ref.invalidate(businessProvider);

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Sign out from AppAuthService
      await AppAuthService.signOut();

      AppLogger.info('All user data cleared successfully');
    } catch (e) {
      AppLogger.error('Error clearing user data: $e');
    }
  }
}
