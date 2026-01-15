import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../dashboards/main_dashboard.dart';
import '../../services/app_auth_service.dart';
import 'package:whizz_merchants/core/design_system/design_system.dart';

class ConfirmationScreen extends StatefulWidget {
  final String email;
  final Map<String, dynamic> userData;

  const ConfirmationScreen({
    super.key,
    required this.email,
    required this.userData,
  });

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _canResend = false;
  int _resendCountdown = 60;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
        _startResendCountdown();
      } else if (mounted) {
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  void _handleConfirmation() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final code = _codeController.text.trim();
        
        // Step 1: Confirm the email
        final result = await AppAuthService.confirmSignUp(
          username: widget.email,
          code: code,
        );

        if (mounted) {
          if (result.success) {
            final localizations = AppLocalizations.of(context)!;
            
            // Show confirmation success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localizations.accountConfirmedSuccessfully),
                backgroundColor: WhizzColors.success,
                duration: const Duration(seconds: 2),
              ),
            );
            
            // Step 2: Auto-login the user with the password from userData
            final password = widget.userData['password'] as String?;

            if (password != null && password.isNotEmpty) {
              // Attempt auto-login
              final signInResult = await AppAuthService.signIn(
                email: widget.email,
                password: password,
              );

              if (mounted) {
                setState(() {
                  _isLoading = false;
                });

                if (signInResult.success) {
                  // Step 3: Navigate to dashboard with valid session
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => const MainDashboard()),
                    (route) => false,
                  );
                } else {
                  // Auto-login failed, show error and redirect to login
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${localizations.accountConfirmedSuccessfully} Please sign in to continue.'),
                      backgroundColor: WhizzColors.primary,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/signin', (route) => false);
                }
              }
            } else {
              // No password available for auto-login, redirect to login
              setState(() {
                _isLoading = false;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '${localizations.accountConfirmedSuccessfully} Please sign in to continue.'),
                  backgroundColor: WhizzColors.primary,
                  duration: const Duration(seconds: 3),
                ),
              );
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/signin', (route) => false);
            }
          } else {
            setState(() {
              _isLoading = false;
            });
            
            final localizations = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    result.message ?? localizations.invalidConfirmationCode),
                backgroundColor: WhizzColors.error,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${AppLocalizations.of(context)!.error}: ${e.toString()}'),
              backgroundColor: WhizzColors.error,
            ),
          );
        }
      }
    }
  }

  void _handleResendCode() async {
    if (!_canResend) return;

    setState(() {
      _canResend = false;
      _resendCountdown = 60;
    });

    _startResendCountdown();

    try {
      await AppAuthService.resendSignUpCode(
        username: widget.email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!
                .confirmationCodeResent(widget.email)),
            backgroundColor: WhizzColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${AppLocalizations.of(context)!.error}: ${e.toString()}'),
            backgroundColor: WhizzColors.error,
          ),
        );
      }
    }
  }

  void _handleBackToSignup() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: AppSpacing.xxl),
                      
                      // Icon
                      Container(
                        width: 80,
                        height: 80,
                        margin: EdgeInsets.only(bottom: AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: WhizzColors.secondary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.md),
                        ),
                        child: Icon(
                          Icons.mark_email_read,
                          size: AppDimensions.iconSizeXXL,
                          color: WhizzColors.secondary,
                        ),
                      ),
                      
                      // Title
                      Text(
                        localizations.confirmYourAccount,
                        style: AppTypography.headlineSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: WhizzColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      SizedBox(height: AppSpacing.md),
                      
                      // Description
                      Text(
                        localizations.confirmationCodeSentTo,
                        style: AppTypography.bodyLarge.copyWith(
                          color: WhizzColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      SizedBox(height: AppSpacing.xs),
                      
                      // Email display
                      Text(
                        widget.email,
                        style: AppTypography.bodyLarge.copyWith(
                          color: WhizzColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      SizedBox(height: AppSpacing.xxl),
                      
                      // Confirmation code field
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: AppTypography.headlineSmall.copyWith(
                          letterSpacing: 8,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          labelText: localizations.confirmationCode,
                          hintText: '123456',
                          prefixIcon: const Icon(Icons.lock_outline),
                          counterText: '',
                        ),
                        maxLength: 6,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return localizations.confirmationCodeRequired;
                          }
                          if (value.trim().length != 6) {
                            return localizations.codeMustBeSixDigits;
                          }
                          return null;
                        },
                      ),
                      
                      SizedBox(height: AppSpacing.xxl),
                      
                      // Confirm button
                      FilledButton(
                        onPressed: _isLoading ? null : _handleConfirmation,
                        style: FilledButton.styleFrom(
                          backgroundColor: WhizzColors.secondary,
                          minimumSize: Size(
                              double.infinity, AppDimensions.buttonHeightLarge),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: AppDimensions.iconSizeMD,
                                height: AppDimensions.iconSizeMD,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      WhizzColors.white),
                                ),
                              )
                            : Text(localizations.confirmAccountButton),
                      ),
                      
                      SizedBox(height: AppSpacing.md),
                      
                      // Resend code button
                      OutlinedButton(
                        onPressed: _canResend ? _handleResendCode : null,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: WhizzColors.secondary),
                          minimumSize: Size(
                              double.infinity, AppDimensions.buttonHeightLarge),
                        ),
                        child: Text(
                          _canResend 
                              ? localizations.resendCode
                              : localizations.resendCodeIn(_resendCountdown),
                        ),
                      ),
                      
                      SizedBox(height: AppSpacing.lg),
                      
                      // Back to signup
                      TextButton(
                        onPressed: _handleBackToSignup,
                        child: Text(
                          localizations.backToSignUp,
                          style: TextStyle(color: WhizzColors.secondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final localizations = AppLocalizations.of(context)!;
    
    return Container(
      padding:
          EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _handleBackToSignup,
            icon: Icon(Icons.arrow_back, size: AppDimensions.iconSizeMD),
          ),
          
          IconButton(
            onPressed: () {
              // TODO: Implement language toggle
            },
            icon: Icon(
              Icons.language,
              color: WhizzColors.secondary,
              size: AppDimensions.iconSizeMD,
            ),
            tooltip: localizations.language,
          ),
        ],
      ),
    );
  }
}
