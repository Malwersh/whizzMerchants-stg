import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design_system/design_system.dart';
import '../core/adaptive/adaptive_widgets.dart';
import '../l10n/app_localizations.dart';
import '../services/cognito_auth_service.dart';
import '../utils/responsive_helper.dart';

class ConfirmForgotPasswordScreen extends ConsumerStatefulWidget {
  final String email;

  const ConfirmForgotPasswordScreen({
    super.key,
    required this.email,
  });

  @override
  ConsumerState<ConfirmForgotPasswordScreen> createState() =>
      _ConfirmForgotPasswordScreenState();
}

class _ConfirmForgotPasswordScreenState
    extends ConsumerState<ConfirmForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _confirmResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final cognitoAuthService = CognitoAuthService();

      await cognitoAuthService.confirmResetPassword(
        email: widget.email,
        newPassword: _newPasswordController.text,
        confirmationCode: _codeController.text,
      );
      
      if (mounted) {
        // Navigate back to login screen
        Navigator.of(context).popUntil((route) => route.isFirst);
        
        final loc = AppLocalizations.of(context)!;
        showAdaptiveSnackBar(
          context: context,
          message: loc.passwordResetSuccessfully,
          type: AdaptiveSnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        String errorMessage = loc.errorOccurred;

        // Provide more specific error messages
        if (e.toString().contains('CodeMismatchException') ||
            e.toString().contains('Invalid verification code')) {
          errorMessage = 'Invalid verification code';
        } else if (e.toString().contains('ExpiredCodeException') ||
            e.toString().contains('Expired code')) {
          errorMessage = 'Verification code has expired';
        } else if (e.toString().contains('InvalidPasswordException')) {
          errorMessage = 'Invalid password format';
        }
        
        showAdaptiveSnackBar(
          context: context,
          message: errorMessage,
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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);

    return Scaffold(
      backgroundColor: WhizzColors.white,
      appBar: AdaptiveAppBar(
        title: Text(
          loc.resetPassword,
          style: AppTypography.headlineSmall.copyWith(
            color: WhizzColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
          ),
        ),
        backgroundColor: WhizzColors.white,
        leading: AdaptiveBackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 600 : (isTablet ? 500 : double.infinity),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(
                ResponsiveHelper.getResponsivePadding(context)
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      loc.enterVerificationCodeSentTo,
                      style: AppTypography.bodyLarge.copyWith(
                        color: WhizzColors.textPrimary,
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.email,
                      style: AppTypography.bodyLarge.copyWith(
                        color: WhizzColors.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                      ),
                    ),
                    SizedBox(height: isMobile ? AppSpacing.lg : AppSpacing.xl),
                    
                    // Verification Code Field - Using AdaptiveTextField
                    AdaptiveTextField(
                      controller: _codeController,
                      label: loc.verificationCode,
                      placeholder: loc.enter6DigitCode,
                      keyboardType: TextInputType.number,
                      prefixIcon: Icon(Icons.security, color: WhizzColors.secondary),
                    ),
                    SizedBox(height: isMobile ? AppSpacing.lg : AppSpacing.xl),

                    // New Password Field - Using AdaptiveTextField.password
                    AdaptiveTextField.password(
                      controller: _newPasswordController,
                      label: loc.newPassword,
                      placeholder: loc.enterYourNewPassword,
                      obscureText: _obscureNewPassword,
                      onToggleObscure: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                    SizedBox(height: isMobile ? AppSpacing.lg : AppSpacing.xl),

                    // Confirm Password Field - Using AdaptiveTextField.password
                    AdaptiveTextField.password(
                      controller: _confirmPasswordController,
                      label: loc.confirmPassword,
                      placeholder: loc.confirmNewPassword,
                      obscureText: _obscureConfirmPassword,
                      onToggleObscure: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    SizedBox(height: isMobile ? AppSpacing.xl : GoldenRatio.xl),

                    // Reset Password Button - Using AdaptiveButton
                    SizedBox(
                      width: double.infinity,
                      height: AppDimensions.buttonHeightLarge,
                      child: AdaptiveButton.secondary(
                        onPressed: _isLoading ? null : _confirmResetPassword,
                        isLoading: _isLoading,
                        child: Text(
                          loc.resetPassword,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
