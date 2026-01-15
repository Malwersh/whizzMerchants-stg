import 'package:flutter/material.dart';
import '../core/design_system/design_system.dart';
import '../core/adaptive/adaptive_widgets.dart';
import '../services/app_auth_service.dart';
import 'confirm_forgot_password_screen.dart';
import '../l10n/app_localizations.dart';
import '../utils/responsive_helper.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  final bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveHelper.isTablet(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);

    return Scaffold(
      backgroundColor: WhizzColors.backgroundPrimary,
      appBar: _buildModernAppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 600 : (isTablet ? 500 : double.infinity),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(
                  ResponsiveHelper.getResponsivePadding(context)),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    final loc = AppLocalizations.of(context)!;
    return AdaptiveAppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.resetPassword,
            style: AppTypography.headlineSmall.copyWith(
              color: WhizzColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
            ),
          ),
          Text(
            loc.recoverYourAccountAccess,
            style: AppTypography.bodyMedium.copyWith(
              color: WhizzColors.textPrimary,
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
            ),
          ),
        ],
      ),
      backgroundColor: WhizzColors.white,
      leading: AdaptiveBackButton(
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildContent() {
    final loc = AppLocalizations.of(context)!;
    final isMobile = ResponsiveHelper.isMobile(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: isMobile ? AppSpacing.lg : AppSpacing.xl),

        // Icon with modern styling
        Container(
          padding: EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xl),
          margin:
              EdgeInsets.only(bottom: isMobile ? AppSpacing.lg : AppSpacing.xl),
          decoration: BoxDecoration(
            color: WhizzColors.grey100,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXL),
            border: Border.all(
              color: WhizzColors.borderLight,
              width: 1,
            ),
            boxShadow: WhizzColors.elevation(2),
          ),
          child: Icon(
            _emailSent ? Icons.mark_email_read : Icons.lock_reset,
            size: ResponsiveHelper.getResponsiveIconSize(context, baseSize: 64),
            color: WhizzColors.primary,
          ),
        ),
        
        // Header Section
        Container(
          padding: EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xl),
          decoration: BoxDecoration(
            color: WhizzColors.white,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXL),
            border: Border.all(
              color: WhizzColors.borderLight,
              width: 1,
            ),
            boxShadow: WhizzColors.elevation(1),
          ),
          child: Column(
            children: [
              Text(
                _emailSent ? loc.checkYourEmail : loc.forgotPasswordQuestion,
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: WhizzColors.textPrimary,
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 24),
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: AppSpacing.sm),
              
              Text(
                _emailSent
                    ? loc.emailSentDescription
                    : loc.resetPasswordDescription,
                style: AppTypography.bodyLarge.copyWith(
                  color: WhizzColors.textPrimary,
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        SizedBox(height: isMobile ? AppSpacing.xl : AppSpacing.xxl),

        if (!_emailSent) ...[
          // Email Form
          Form(
            key: _formKey,
            child: Column(
              children: [
                _buildModernTextField(),

                SizedBox(height: isMobile ? AppSpacing.xl : AppSpacing.xxl),

                // Send Reset Link Button - Using AdaptiveButton
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeightLarge,
                  child: AdaptiveButton(
                    onPressed: _isLoading ? null : _sendResetLink,
                    isLoading: _isLoading,
                    color: WhizzColors.black,
                    textColor: Colors.white,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isLoading) ...[
                          Icon(
                            Icons.email_outlined,
                            color: Colors.white,
                            size: ResponsiveHelper.getResponsiveIconSize(
                                context,
                                baseSize: 20),
                          ),
                          SizedBox(width: AppSpacing.sm),
                        ],
                        Text(
                          _isLoading ? loc.sending : loc.sendResetCode,
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveHelper.getResponsiveFontSize(
                                context, 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Success State - Email Sent
          Container(
            padding: EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xl),
            decoration: BoxDecoration(
              color: WhizzColors.grey100,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXL),
              border: Border.all(
                color: WhizzColors.borderLight,
                width: 1,
              ),
              boxShadow: WhizzColors.elevation(2),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.mark_email_read,
                  size: ResponsiveHelper.getResponsiveIconSize(context,
                      baseSize: 64),
                  color: WhizzColors.success,
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  loc.verificationCodeSentTitle,
                  style: AppTypography.headlineSmall.copyWith(
                    color: WhizzColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize:
                        ResponsiveHelper.getResponsiveFontSize(context, 20),
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  loc.checkSpamFolder,
                  style: AppTypography.bodyMedium.copyWith(
                    color: WhizzColors.textPrimary,
                    fontSize:
                        ResponsiveHelper.getResponsiveFontSize(context, 14),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          SizedBox(height: isMobile ? AppSpacing.xl : AppSpacing.xxl),

          // Continue Button - Using AdaptiveButton
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeightLarge,
            child: AdaptiveButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConfirmForgotPasswordScreen(
                      email: _emailController.text,
                    ),
                  ),
                );
              },
              color: WhizzColors.black,
              textColor: Colors.white,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: ResponsiveHelper.getResponsiveIconSize(context,
                        baseSize: 20),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    loc.continueToVerification,
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize:
                          ResponsiveHelper.getResponsiveFontSize(context, 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        SizedBox(height: isMobile ? AppSpacing.xl : AppSpacing.xxl),

        // Back to Login - Using AdaptiveButton.text
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              loc.rememberYourPassword,
              style: AppTypography.bodyMedium.copyWith(
                color: WhizzColors.textPrimary,
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
              ),
            ),
            AdaptiveButton.text(
              onPressed: () => Navigator.of(context).pop(),
              color: WhizzColors.secondary,
              child: Text(
                loc.signIn,
                style: AppTypography.bodyMedium.copyWith(
                  color: WhizzColors.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernTextField() {
    final loc = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: WhizzColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
        border: Border.all(
          color: WhizzColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.grey200.withValues(alpha: 0.5),
            blurRadius: AppSpacing.xs,
            offset: Offset(0, AppSpacing.xxs),
          ),
        ],
      ),
      child: AdaptiveTextField.email(
        controller: _emailController,
        label: loc.emailAddress,
        placeholder: loc.enterYourEmail,
      ),
    );
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AppAuthService.forgotPassword(
        email: _emailController.text.trim(),
      );

      if (result.success) {
        // Show success message and navigate to confirmation screen
        if (mounted) {
          final loc = AppLocalizations.of(context)!;
          showAdaptiveSnackBar(
            context: context,
            message: loc.verificationCodeSent,
            type: AdaptiveSnackBarType.success,
          );

          // Navigate to confirmation screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConfirmForgotPasswordScreen(
                email: _emailController.text.trim(),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          showAdaptiveSnackBar(
            context: context,
            message: result.message,
            type: AdaptiveSnackBarType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        showAdaptiveSnackBar(
          context: context,
          message: loc.failedToSendVerificationCode(e.toString()),
          type: AdaptiveSnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ignore: unused_element
  Future<void> _resendResetLink() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AppAuthService.forgotPassword(
        email: _emailController.text.trim(),
      );

      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        showAdaptiveSnackBar(
          context: context,
          message: result.success
              ? loc.verificationCodeSentAgain
              : '${loc.failedToResend}: ${result.message}',
          type: result.success
              ? AdaptiveSnackBarType.success
              : AdaptiveSnackBarType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        showAdaptiveSnackBar(
          context: context,
          message: '${loc.failedToResend}: $e',
          type: AdaptiveSnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
