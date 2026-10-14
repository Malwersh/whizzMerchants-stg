import '../delete_account_screen.dart';
import '../../services/account_deletion_service.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../registration_form_screen.dart';
import '../merchant_status_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/language_provider_riverpod.dart';
import '../../providers/auth_provider_riverpod.dart';
import '../../providers/session_provider.dart';
import '../../providers/business_provider.dart';
import '../../services/app_auth_service.dart';
import '../../models/business.dart';
import '../../core/design_system/design_system.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Phone OTP login
  final _loginFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _codeSent = false;
  bool _isBusy = false;
  String? _phoneE164;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Note: Token validation and clearing is handled by SessionProvider
    // We don't automatically clear tokens here to allow proper persistence
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WhizzColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header with logo and title
            _buildModernHeader(),

            // Tab bar
            _buildModernTabBar(),
            FutureBuilder<bool>(
              future: AccountDeletionService.hasSavedAccountReceipt(),
              builder: (context, snapshot) => snapshot.data == true
                  ? TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeleteAccountScreen(scope: 'ACCOUNT'))), child: const Text('متابعة طلب حذف الحساب'))
                  : const SizedBox.shrink(),
            ),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildLoginTab(), _buildSignupTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: WhizzColors.surface,
        boxShadow: [
          BoxShadow(
            color: WhizzColors.shadow.withValues(alpha: 0.04),
            blurRadius: AppSpacing.sm,
            offset: Offset(0, AppSpacing.xxs),
          ),
        ],
      ),
      child: Column(children: [SizedBox(height: AppSpacing.md)]),
    );
  }

  Widget _buildModernTabBar() {
    final localizations = AppLocalizations.of(context)!;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      padding: EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: WhizzColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
        border: Border.all(color: WhizzColors.borderPrimary, width: 1),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.shadow.withValues(alpha: 0.08),
            blurRadius: AppSpacing.md,
            offset: Offset(0, AppSpacing.xxs),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: WhizzColors.secondary,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
          boxShadow: WhizzColors.elevation(2),
        ),
        labelColor: WhizzColors.primaryDark,
        unselectedLabelColor: WhizzColors.primaryDark,
        labelStyle: AppTypography.labelLarge.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 16.0, // Increased for better readability
        ),
        unselectedLabelStyle: AppTypography.labelLarge.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 16.0, // Increased for better readability
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: [
          Tab(
            height: 56.0, // Material Design recommended height for tabs
            text: localizations.login,
          ),
          Tab(
            height: 56.0, // Material Design recommended height for tabs
            text: localizations.signUp,
          ),
        ],
      ),
    );
  }

  // ===================== Phone OTP login =====================

  Widget _buildLoginTab() {
    final localizations = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: AppSpacing.lg),

            if (!_codeSent) ...[
              _buildModernTextField(
                controller: _phoneController,
                label: localizations.phoneNumber,
                hint: '07XX XXX XXXX',
                icon: Icons.phone_iphone,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return localizations.phoneRequired;
                  }
                  if (AppAuthService.normalizeIraqiPhone(value) == null) {
                    return localizations.invalidIraqiPhone;
                  }
                  return null;
                },
              ),
            ] else ...[
              Text(
                localizations.otpSentTo(_phoneE164 ?? ''),
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  color: WhizzColors.textSecondary,
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              _buildModernTextField(
                controller: _otpController,
                label: localizations.verificationCode,
                hint: '••••••',
                icon: Icons.sms_outlined,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null ||
                      !RegExp(r'^\d{6}$').hasMatch(value.trim())) {
                    return localizations.enterSixDigitCode;
                  }
                  return null;
                },
              ),
              SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _isBusy
                        ? null
                        : () => setState(() {
                            _codeSent = false;
                            _otpController.clear();
                            _resendTimer?.cancel();
                          }),
                    child: Text(localizations.changeNumber),
                  ),
                  TextButton(
                    onPressed: (_resendSeconds > 0 || _isBusy)
                        ? null
                        : () => _sendCode(isResend: true),
                    child: Text(
                      _resendSeconds > 0
                          ? localizations.resendCodeIn(_resendSeconds)
                          : localizations.resendCode,
                    ),
                  ),
                ],
              ),
            ],

            SizedBox(height: AppSpacing.xxl),

            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: WhizzColors.primary,
                borderRadius: BorderRadius.circular(
                  AppDimensions.borderRadiusLG,
                ),
                boxShadow: WhizzColors.elevation(3),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isBusy
                      ? null
                      : () => _codeSent ? _verifyCode() : _sendCode(),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.borderRadiusLG,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isBusy)
                          SizedBox(
                            width: AppSpacing.lg,
                            height: AppSpacing.lg,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: WhizzColors.secondary,
                            ),
                          )
                        else
                          Icon(
                            _codeSent ? Icons.verified_user : Icons.sms,
                            color: WhizzColors.secondary,
                            size: AppSpacing.lg,
                          ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          _codeSent
                              ? localizations.verifyAndSignIn
                              : localizations.sendCode,
                          style: AppTypography.titleMedium.copyWith(
                            color: WhizzColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: AppSpacing.xl),

            // Language Switcher
            Consumer(
              builder: (context, ref, child) {
                final currentLocale = ref.watch(languageProviderRiverpod);
                final languageNotifier = ref.read(
                  languageProviderRiverpod.notifier,
                );
                final isEnglish = currentLocale.languageCode == 'en';

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // English button
                    GestureDetector(
                      onTap: () {
                        if (!isEnglish) {
                          languageNotifier.toggleLanguage();
                        }
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                          horizontal: AppSpacing.md,
                        ),
                        child: Text(
                          'English',
                          style: AppTypography.bodyMedium.copyWith(
                            color: isEnglish
                                ? WhizzColors.secondary
                                : WhizzColors.textSecondary,
                            fontWeight: isEnglish
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),

                    // Spacing between languages
                    SizedBox(width: AppSpacing.xs),

                    // Arabic button
                    GestureDetector(
                      onTap: () {
                        if (isEnglish) {
                          languageNotifier.toggleLanguage();
                        }
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                          horizontal: AppSpacing.md,
                        ),
                        child: Text(
                          'عربي',
                          style: AppTypography.bodyMedium.copyWith(
                            color: !isEnglish
                                ? WhizzColors.secondary
                                : WhizzColors.textSecondary,
                            fontWeight: !isEnglish
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: WhizzColors.secondary)),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) t.cancel();
    });
  }

  Future<void> _sendCode({bool isResend = false}) async {
    final loc = AppLocalizations.of(context)!;
    if (!isResend && !_loginFormKey.currentState!.validate()) return;

    final phone = isResend
        ? _phoneE164
        : AppAuthService.normalizeIraqiPhone(_phoneController.text);
    if (phone == null) return;

    setState(() => _isBusy = true);
    try {
      final sent = await AppAuthService.startPhoneSignIn(phone);
      if (!mounted) return;
      if (sent) {
        setState(() {
          _phoneE164 = phone;
          _codeSent = true;
          _otpController.clear();
        });
        _startResendCountdown();
      } else {
        _showError('Unexpected step: ${AppAuthService.lastSignInStep}');
      }
    } on PhoneAuthException catch (e) {
      _showError(
        e.error == PhoneAuthError.notRegistered
            ? loc.phoneNotRegistered
            : 'OTP send failed: ${e.detail ?? e.error}',
      );
    } catch (e) {
      _showError('OTP error: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _verifyCode() async {
    final loc = AppLocalizations.of(context)!;
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isBusy = true);
    try {
      final response = await AppAuthService.confirmPhoneCode(
        _otpController.text.trim(),
      );
      if (!mounted) return;

      if (response.success) {
        _resendTimer?.cancel();
        ref.read(authProviderRiverpod.notifier).setAuthenticated();
        if (response.businesses.isNotEmpty) {
          final business = response.businesses.first;
          final businessId = business['businessId'];
          if (businessId != null) {
            ref
                .read(sessionProvider.notifier)
                .setSessionWithBusinessData(businessId, business);
            ref.invalidate(businessProvider);
          }
        }
        return;
      }

      if (response.accountStatus == 'pending') {
        final Map<String, dynamic> b = response.businesses.isNotEmpty
            ? response.businesses.first
            : {};
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => MerchantStatusScreen(
              status: 'pending',
              business: Business(
                id: b['businessId']?.toString() ?? 'pending_business',
                name: b['businessName']?.toString() ?? '',
                email: b['email']?.toString() ?? '',
                status: 'pending',
                businessType: BusinessType.restaurant,
                address: '',
                phone: _phoneE164 ?? '',
                city: '',
                district: '',
                country: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ),
          ),
          (route) => false,
        );
        return;
      }

      if (response.message == 'INVALID_CODE') {
        _showError(loc.invalidOtp);
      } else {
        setState(() {
          _codeSent = false;
          _otpController.clear();
        });
        _showError(loc.otpExpired);
      }
    } catch (_) {
      _showError(loc.otpSendFailed);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Widget _buildSignupTab() {
    final localizations = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: AppSpacing.md),

          // Features list - Compact version
          _buildCompactFeaturesList(),

          SizedBox(height: AppSpacing.md),

          // Create account button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: WhizzColors.primary,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
              boxShadow: WhizzColors.elevation(3),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegistrationFormScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(
                  AppDimensions.borderRadiusLG,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.business_center,
                        color: WhizzColors.secondary,
                        size: AppSpacing.lg,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        localizations.startBusinessRegistration,
                        style: AppTypography.titleMedium.copyWith(
                          color: WhizzColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: AppSpacing.md),

          // Terms and conditions - Compact
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: WhizzColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
              border: Border.all(
                color: WhizzColors.primary.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Text(
              localizations
                  .byCreatingAnAccountYouAgreeToOurTermsOfServiceAndPrivacyPolicy,
              style: AppTypography.bodySmall.copyWith(
                color: WhizzColors.onSurfaceVariant,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: WhizzColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
        border: Border.all(color: WhizzColors.secondary, width: 1),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.shadow.withValues(alpha: 0.04),
            blurRadius: AppSpacing.xs,
            offset: Offset(0, AppSpacing.xxs),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        style: AppTypography.bodyLarge.copyWith(color: WhizzColors.onSurface),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Container(
            margin: EdgeInsets.all(AppSpacing.sm),
            padding: EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: WhizzColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
            ),
            child: Icon(
              icon,
              color: WhizzColors.secondary,
              size: AppSpacing.lg,
            ),
          ),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: WhizzColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
            borderSide: BorderSide(color: WhizzColors.secondary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
            borderSide: BorderSide(color: WhizzColors.error, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
            borderSide: BorderSide(color: WhizzColors.error, width: 2),
          ),
          labelStyle: AppTypography.bodyMedium.copyWith(
            color: WhizzColors.secondary,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: AppTypography.bodyMedium.copyWith(
            color: WhizzColors.onSurfaceVariant,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
    );
  }

  Widget _buildCompactFeaturesList() {
    final localizations = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: WhizzColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
        border: Border.all(
          color: WhizzColors.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildCompactFeatureItem(
            Icons.store,
            localizations.completeBusinessRegistration,
            WhizzColors.primary,
          ),
          SizedBox(height: AppSpacing.xs),
          _buildCompactFeatureItem(
            Icons.verified_user,
            localizations.secureAndVerified,
            WhizzColors.secondary,
          ),
          SizedBox(height: AppSpacing.xs),
          _buildCompactFeatureItem(
            Icons.dashboard,
            localizations.fullDashboardAccess,
            WhizzColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFeatureItem(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
          ),
          child: Icon(icon, color: color, size: AppSpacing.md),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              color: WhizzColors.primaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
