import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_auth_service.dart';
import '../l10n/app_localizations.dart';
import '../core/design_system/design_system.dart';
import '../core/adaptive/adaptive_widgets.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AppAuthService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: 'Password changed successfully',
          type: AdaptiveSnackBarType.success,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: 'Failed to change password: $e',
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

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              WhizzColors.secondaryContainer,
              WhizzColors.backgroundPrimary,
              WhizzColors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(loc),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: _buildContent(loc),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar(AppLocalizations loc) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white, // Changed to white background
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
                alpha: 0.1), // Updated shadow color for white background
            blurRadius: AppSpacing.sm,
            offset: Offset(0, AppSpacing.xs),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: WhizzColors.secondary.withValues(
                  alpha: 0.1), // Updated for better contrast on white
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
              border: Border.all(
                color: WhizzColors.secondary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              icon:
                  Icon(Icons.arrow_back_rounded,
                  color:
                      WhizzColors.secondary), // Updated icon color for contrast
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.changePassword,
                  style: AppTypography.headlineSmall.copyWith(
                    color: WhizzColors
                        .secondary, // Updated text color for contrast on white
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Update your account password',
                  style: AppTypography.bodyMedium.copyWith(
                    color: WhizzColors.secondary
                        .withValues(alpha: 0.7), // Updated for white background
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AppLocalizations loc) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // Current Password Field
          _buildModernTextField(
            controller: _currentPasswordController,
            label: 'Current Password',
            hint: 'Enter your current password',
            icon: Icons.lock_outline,
            obscureText: _obscureCurrentPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureCurrentPassword 
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: WhizzColors.secondary,
              ),
              onPressed: () {
                setState(() {
                  _obscureCurrentPassword = !_obscureCurrentPassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Current password is required';
              }
              return null;
            },
          ),
          
          SizedBox(height: AppSpacing.lg),

          // New Password Field
          _buildModernTextField(
            controller: _newPasswordController,
            label: 'New Password',
            hint: 'Enter your new password',
            icon: Icons.lock_reset,
            obscureText: _obscureNewPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPassword 
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: WhizzColors.secondary,
              ),
              onPressed: () {
                setState(() {
                  _obscureNewPassword = !_obscureNewPassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a new password';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              if (value == _currentPasswordController.text) {
                return 'New password must be different from current password';
              }
              return null;
            },
          ),
          
          SizedBox(height: AppSpacing.lg),

          // Confirm Password Field
          _buildModernTextField(
            controller: _confirmPasswordController,
            label: 'Confirm New Password',
            hint: 'Confirm your new password',
            icon: Icons.lock_outline,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword 
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: WhizzColors.secondary,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your new password';
              }
              if (value != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          
          SizedBox(height: AppSpacing.xxl),
          
          // Change Password Button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  WhizzColors.secondary,
                  WhizzColors.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
              boxShadow: [
                BoxShadow(
                  color: WhizzColors.secondary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: WhizzColors.secondary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isLoading ? null : _changePassword,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusLG),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isLoading) ...[
                        AdaptiveLoadingIndicator(
                          color: WhizzColors.secondary,
                          size: AppDimensions.iconSizeMD,
                        ),
                        SizedBox(width: AppSpacing.sm),
                      ] else ...[
                        Icon(
                          Icons.security,
                          color: WhizzColors.secondary,
                          size: AppDimensions.iconSizeMD,
                        ),
                        SizedBox(width: AppSpacing.sm),
                      ],
                      Text(
                        _isLoading ? 'Changing Password...' : 'Change Password',
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
        ],
      ),
    );
  }
  
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: WhizzColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
        border: Border.all(
          color: WhizzColors.secondary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.secondary.withValues(alpha: 0.08),
            blurRadius: AppSpacing.xxs,
            offset: Offset(0, AppSpacing.xs),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        style: AppTypography.bodyLarge.copyWith(
          color: WhizzColors.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Container(
            margin: EdgeInsets.all(AppSpacing.sm),
            padding: EdgeInsets.all(AppSpacing.xxs),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  WhizzColors.secondary.withValues(alpha: 0.1),
                  WhizzColors.secondary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
              border: Border.all(
                color: WhizzColors.secondary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: WhizzColors.secondary,
              size: AppDimensions.iconSizeMD,
            ),
          ),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: WhizzColors.white,
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
            color: WhizzColors.textPrimary,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
    );
  }
}
