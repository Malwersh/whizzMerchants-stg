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
import '../../services/recaptcha_service.dart';
import '../../models/business.dart';
import '../../core/design_system/design_system.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Login form
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _obscureLoginPassword = true;
  
  // Forgot password form
  final _forgotPasswordFormKey = GlobalKey<FormState>();
  final _forgotPasswordEmailController = TextEditingController();
  final _forgotPasswordCodeController = TextEditingController();
  final _forgotPasswordNewPasswordController = TextEditingController();
  final _forgotPasswordConfirmPasswordController = TextEditingController();
  bool _forgotPasswordSent = false;
  bool _obscureForgotPasswordNewPassword = true;
  bool _obscureForgotPasswordConfirmPassword = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Note: Token validation and clearing is handled by SessionProvider
    // We don't automatically clear tokens here to allow proper persistence
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _forgotPasswordEmailController.dispose();
    _forgotPasswordCodeController.dispose();
    _forgotPasswordNewPasswordController.dispose();
    _forgotPasswordConfirmPasswordController.dispose();
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

              // Tab views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLoginTab(),
                    _buildSignupTab(),
                    _buildForgotPasswordTab(),
                  ],
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
          AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, AppSpacing.lg
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
      child: Column(
        children: [
          SizedBox(height: AppSpacing.md),
        ],
      ),
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
        border: Border.all(
          color: WhizzColors.borderPrimary,
          width: 1,
        ),
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
          Tab(
            height: 56.0, // Material Design recommended height for tabs
            text: localizations.reset,
          ),
        ],
      ),
    );
  }
  
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
            
            // Email field
            _buildModernTextField(
              controller: _loginEmailController,
              label: localizations.email,
              hint: localizations.enterYourEmail,
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            
            SizedBox(height: AppSpacing.lg),
            
            // Password field
            _buildModernTextField(
              controller: _loginPasswordController,
              label: localizations.password,
              hint: localizations.enterYourPassword,
              icon: Icons.lock_outline,
              obscureText: _obscureLoginPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureLoginPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: WhizzColors.primary,
                ),
                onPressed: () {
                  setState(() {
                    _obscureLoginPassword = !_obscureLoginPassword;
                  });
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                return null;
              },
            ),
            
            SizedBox(height: AppSpacing.xxl),
            
            // Login button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: WhizzColors.primary,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusLG),
                boxShadow: WhizzColors.elevation(3),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleLogin(),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusLG),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.login,
                          color: WhizzColors.secondary,
                          size: AppSpacing.lg,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          localizations.signIn,
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
                final languageNotifier =
                    ref.read(languageProviderRiverpod.notifier);
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
                            fontWeight:
                                isEnglish ? FontWeight.bold : FontWeight.normal,
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
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusLG),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(vertical: AppSpacing.lg),
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
  
  Widget _buildForgotPasswordTab() {
    final localizations = AppLocalizations.of(context)!;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Form(
        key: _forgotPasswordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: AppSpacing.lg),
            
            if (!_forgotPasswordSent) ...[
              // Email field
              _buildModernTextField(
                controller: _forgotPasswordEmailController,
                label: localizations.email,
                hint: 'Enter your registered email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: AppSpacing.xxl),
              
              // Send verification code button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: WhizzColors.primary,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusLG),
                  boxShadow: WhizzColors.elevation(3),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleForgotPassword(),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadiusLG),
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.email_outlined,
                            color: WhizzColors.secondary,
                            size: AppSpacing.lg,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            'Send Verification Code',
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
            ] else ...[
              // Verification code field
              _buildModernTextField(
                controller: _forgotPasswordCodeController,
                label: 'Verification Code',
                hint: 'Enter 6-digit code',
                icon: Icons.vpn_key,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Verification code is required';
                  }
                  if (value.length != 6) {
                    return 'Code must be 6 digits';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: AppSpacing.lg),
              
              // New password field
              _buildModernTextField(
                controller: _forgotPasswordNewPasswordController,
                label: 'New Password',
                hint: 'Enter your new password',
                icon: Icons.lock_outline,
                obscureText: _obscureForgotPasswordNewPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureForgotPasswordNewPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: WhizzColors.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureForgotPasswordNewPassword =
                          !_obscureForgotPasswordNewPassword;
                    });
                  },
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'New password is required';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: AppSpacing.lg),
              
              // Confirm password field
              _buildModernTextField(
                controller: _forgotPasswordConfirmPasswordController,
                label: 'Confirm Password',
                hint: 'Confirm your new password',
                icon: Icons.lock_outline,
                obscureText: _obscureForgotPasswordConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureForgotPasswordConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: WhizzColors.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureForgotPasswordConfirmPassword =
                          !_obscureForgotPasswordConfirmPassword;
                    });
                  },
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _forgotPasswordNewPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: AppSpacing.xxl),
              
              // Reset password button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: WhizzColors.primary,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusLG),
                  boxShadow: WhizzColors.elevation(3),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleConfirmForgotPassword(),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadiusLG),
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: WhizzColors.secondary,
                            size: AppSpacing.lg,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            'Reset Password',
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
              
              SizedBox(height: AppSpacing.lg),
              
              // Resend code button
              TextButton.icon(
                onPressed: () => _handleResendEmail(),
                icon: Icon(
                  Icons.refresh,
                  color: WhizzColors.primary,
                  size: AppSpacing.lg,
                ),
                label: Text(
                  'Resend Code',
                  style: AppTypography.bodyLarge.copyWith(
                    color: WhizzColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            
            SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
  
  void _handleLogin() async {
    if (_loginFormKey.currentState!.validate()) {
      final email = _loginEmailController.text.trim();
      final password = _loginPasswordController.text.trim();
      
      // Get reCAPTCHA token
      final recaptchaToken = await RecaptchaService.getToken('LOGIN');
      if (recaptchaToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.recaptchaVerificationFailed,
              style: TextStyle(color: WhizzColors.secondary),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      // Show loading with shorter duration
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Signing in...',
                style: TextStyle(color: WhizzColors.secondary),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 10),
        ),
      );
      
      try {
        // Use AppAuthService for consistent authentication and token storage
        final response = await AppAuthService.signIn(
          email: email,
          password: password,
          recaptchaToken: recaptchaToken,
        );

        if (mounted) {
          // Hide loading snackbar immediately
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          
          if (response.success) {
            // CRITICAL: Update auth provider to reflect authenticated state
            ref.read(authProviderRiverpod.notifier).setAuthenticated();
            
            // CRITICAL: Store business session with full business data to avoid API call
            if (response.businesses.isNotEmpty) {
              final business = response.businesses.first;
              final businessId = business['businessId'];
              if (businessId != null) {
                // Use setSessionWithBusinessData to store complete business info
                ref.read(sessionProvider.notifier).setSessionWithBusinessData(businessId, business);
                
                // Invalidate business provider to trigger refresh
                ref.invalidate(businessProvider);
              }
            }
            
            // Success - show brief success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Login successful! Welcome back.',
                  style: TextStyle(color: WhizzColors.secondary),
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                duration: const Duration(seconds: 2),
              ),
            );
            
          } else {
            // Check if this is a pending status case
            if (response.accountStatus == 'pending') {
              
              // Create a mock business object for the status screen
              final Business mockBusiness = Business(
                id: 'pending_business',
                name: 'Pending Business',
                email: email,
                status: 'pending',
                businessType: BusinessType.restaurant,
                address: '',
                phone: '',
                city: '',
                district: '',
                country: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              
              // Navigate to MerchantStatusScreen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => MerchantStatusScreen(
                    status: 'pending',
                    business: mockBusiness,
                  ),
                ),
                (route) => false,
              );
              return;
            }
            
            // Show error message for other cases
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  response.message.isNotEmpty
                      ? response.message
                      : 'Failed to sign in',
                  style: TextStyle(color: WhizzColors.secondary),
                ),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          // Hide loading snackbar
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: ${e.toString()}',
                style: TextStyle(color: WhizzColors.secondary),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }
  
  void _handleForgotPassword() async {
    if (_forgotPasswordFormKey.currentState!.validate()) {
      final email = _forgotPasswordEmailController.text.trim();
      
      try {
        // First check user status before sending reset code
        final userStatus = await AppAuthService.checkUserStatus(email: email);
        
        if (mounted) {
          if (userStatus.exists && userStatus.isConfirmed) {
            // Account exists and is confirmed - proceed with password reset
            final result = await AppAuthService.forgotPassword(email: email);
            
            if (result.success) {
              setState(() {
                _forgotPasswordSent = true;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Verification code sent to $email',
                    style: TextStyle(color: WhizzColors.secondary),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.tertiary,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result.message.isNotEmpty
                        ? result.message
                        : 'Failed to send verification code',
                    style: TextStyle(color: WhizzColors.secondary),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          } else if (userStatus.exists && !userStatus.isConfirmed) {
            // Account exists but is not confirmed - navigate to comprehensive registration for email verification
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RegistrationFormScreen(),
              ),
            );
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Your account exists but is not verified. Please complete the registration process including email verification.',
                  style: TextStyle(color: WhizzColors.secondary),
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          } else {
            // Account doesn't exist - navigate to comprehensive registration
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RegistrationFormScreen(),
              ),
            );
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No account found with this email. Please complete business registration to create an account.',
                  style: TextStyle(color: WhizzColors.secondary),
                ),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: ${e.toString()}',
                style: TextStyle(color: WhizzColors.secondary),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
  
  void _handleConfirmForgotPassword() async {
    if (_forgotPasswordFormKey.currentState!.validate()) {
      final email = _forgotPasswordEmailController.text.trim();
      final code = _forgotPasswordCodeController.text.trim();
      final newPassword = _forgotPasswordNewPasswordController.text.trim();
      
      try {
        final result = await AppAuthService.confirmForgotPassword(
          email: email,
          confirmationCode: code,
          newPassword: newPassword,
        );
        
        if (mounted) {
          if (result.success) {
            // Reset the form and go back to login
            setState(() {
              _forgotPasswordSent = false;
              _forgotPasswordEmailController.clear();
              _forgotPasswordCodeController.clear();
              _forgotPasswordNewPasswordController.clear();
              _forgotPasswordConfirmPasswordController.clear();
            });
            _tabController.animateTo(0); // Go back to login tab
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Password reset successfully! You can now sign in with your new password.',
                  style: TextStyle(color: WhizzColors.secondary),
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result.message.isNotEmpty
                      ? result.message
                      : 'Failed to reset password',
                  style: TextStyle(color: WhizzColors.secondary),
                ),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: ${e.toString()}',
                style: TextStyle(color: WhizzColors.secondary),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
  
  void _handleResendEmail() async {
    final email = _forgotPasswordEmailController.text.trim();
    if (email.isNotEmpty) {
      try {
        final result = await AppAuthService.forgotPassword(email: email);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.success 
                ? 'Verification code sent again!'
                : 'Failed to resend code: ${result.message}'),
              backgroundColor: result.success ? Colors.green : Theme.of(context).colorScheme.error,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to resend code: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
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
        border: Border.all(
          color: WhizzColors.secondary,
          width: 1,
        ),
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
        style: AppTypography.bodyLarge.copyWith(
          color: WhizzColors.onSurface,
        ),
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
            borderSide: BorderSide(
              color: WhizzColors.secondary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
            borderSide: BorderSide(
              color: WhizzColors.error,
              width: 2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
            borderSide: BorderSide(
              color: WhizzColors.error,
              width: 2,
            ),
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
          child: Icon(
            icon,
            color: color,
            size: AppSpacing.md,
          ),
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
