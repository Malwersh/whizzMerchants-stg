import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_auth_service.dart';
import '../l10n/app_localizations.dart';
import '../core/design_system/golden_ratio_constants.dart';
import '../core/design_system/typography_system.dart';
import '../core/theme/whizz_colors.dart';

class ChangePasswordBottomDrawer extends ConsumerStatefulWidget {
  const ChangePasswordBottomDrawer({super.key});

  @override
  ConsumerState<ChangePasswordBottomDrawer> createState() =>
      _ChangePasswordBottomDrawerState();

  /// Static method to show the bottom drawer
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ChangePasswordBottomDrawer(),
    );
  }
}

class _ChangePasswordBottomDrawerState
    extends ConsumerState<ChangePasswordBottomDrawer> {
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

    final loc = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
    });

    try {
      await AppAuthService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: WhizzColors.onSecondary),
                SizedBox(width: GoldenRatio.spacing12),
                Text(
                  loc.passwordChangedSuccessfully,
                  style: TypographySystem.bodyMedium.copyWith(
                    color: WhizzColors.onSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            backgroundColor: WhizzColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GoldenRatio.radiusMd),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: GoldenRatio.spacing12),
                Expanded(
                  child: Text(
                    '${loc.failedToChangePassword}: $e',
                    style: TypographySystem.bodyMedium.copyWith(
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
              borderRadius: BorderRadius.circular(GoldenRatio.radiusMd),
            ),
          ),
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

    return Container(
      decoration: BoxDecoration(
        color: WhizzColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(GoldenRatio.radiusXl),
          topRight: Radius.circular(GoldenRatio.radiusXl),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: GoldenRatio.spacing20,
            offset: Offset(0, -GoldenRatio.spacing8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: EdgeInsets.only(top: GoldenRatio.spacing12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: WhizzColors.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.all(GoldenRatio.spacing24),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(GoldenRatio.spacing12),
                      decoration: BoxDecoration(
                        color: WhizzColors.secondary.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(GoldenRatio.radiusMd),
                      ),
                      child: Icon(
                        Icons.security,
                        color: WhizzColors.secondary,
                        size: GoldenRatio.spacing24,
                      ),
                    ),
                    SizedBox(width: GoldenRatio.spacing16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.changePassword,
                            style: TypographySystem.headlineSmall.copyWith(
                              color: WhizzColors.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            loc.updateAccountPassword,
                            style: TypographySystem.bodyMedium.copyWith(
                              color: WhizzColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: WhizzColors.surfaceVariant,
                        foregroundColor: WhizzColors.onSurfaceVariant,
                      ),
                      icon: Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),

              // Form content
              Padding(
                padding: EdgeInsets.fromLTRB(
                  GoldenRatio.spacing24,
                  0,
                  GoldenRatio.spacing24,
                  GoldenRatio.spacing24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Current Password Field
                      _buildModernTextField(
                        controller: _currentPasswordController,
                        label: loc.currentPassword,
                        hint: loc.enterCurrentPassword,
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
                              _obscureCurrentPassword =
                                  !_obscureCurrentPassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return loc.currentPasswordRequired;
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: GoldenRatio.spacing20),

                      // New Password Field
                      _buildModernTextField(
                        controller: _newPasswordController,
                        label: loc.newPassword,
                        hint: loc.enterYourNewPassword,
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
                            return loc.newPasswordRequired;
                          }
                          if (value.length < 8) {
                            return loc.passwordMinLength;
                          }
                          if (value == _currentPasswordController.text) {
                            return loc.passwordMustBeDifferent;
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: GoldenRatio.spacing20),

                      // Confirm Password Field
                      _buildModernTextField(
                        controller: _confirmPasswordController,
                        label: loc.confirmPassword,
                        hint: loc.confirmNewPassword,
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
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return loc.confirmPasswordRequired;
                          }
                          if (value != _newPasswordController.text) {
                            return loc.passwordsDoNotMatch;
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: GoldenRatio.xl),

                      // Change Password Button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              WhizzColors.primary,
                              WhizzColors.primaryDark,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius:
                              BorderRadius.circular(GoldenRatio.radiusLg),
                          boxShadow: [
                            BoxShadow(
                              color: WhizzColors.primary.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: WhizzColors.primary.withValues(alpha: 0.2),
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
                                BorderRadius.circular(GoldenRatio.radiusLg),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: GoldenRatio.spacing18),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isLoading) ...[
                                    SizedBox(
                                      width: GoldenRatio.spacing20,
                                      height: GoldenRatio.spacing20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: WhizzColors.secondary,
                                      ),
                                    ),
                                    SizedBox(width: GoldenRatio.spacing12),
                                  ] else ...[
                                    Icon(
                                      Icons.security,
                                      color: WhizzColors.secondary,
                                      size: GoldenRatio.spacing20,
                                    ),
                                    SizedBox(width: GoldenRatio.spacing12),
                                  ],
                                  Text(
                                    _isLoading
                                        ? loc.changingPassword
                                        : loc.changePassword,
                                    style:
                                        TypographySystem.titleMedium.copyWith(
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

                      SizedBox(height: GoldenRatio.spacing24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
        color: WhizzColors.surface,
        borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
        border: Border.all(
          color: WhizzColors.secondary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.secondary.withValues(alpha: 0.08),
            blurRadius: GoldenRatio.spacing8,
            offset: Offset(0, GoldenRatio.spacing4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        style: TypographySystem.bodyLarge.copyWith(
          color: WhizzColors.onSurface,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Container(
            margin: EdgeInsets.all(GoldenRatio.spacing12),
            padding: EdgeInsets.all(GoldenRatio.spacing8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  WhizzColors.secondary.withValues(alpha: 0.1),
                  WhizzColors.secondary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(GoldenRatio.radiusMd),
              border: Border.all(
                color: WhizzColors.secondary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: WhizzColors.secondary,
              size: GoldenRatio.spacing20,
            ),
          ),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: WhizzColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
            borderSide: BorderSide(
              color: WhizzColors.secondary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
            borderSide: BorderSide(
              color: WhizzColors.error,
              width: 2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
            borderSide: BorderSide(
              color: WhizzColors.error,
              width: 2,
            ),
          ),
          labelStyle: TypographySystem.bodyMedium.copyWith(
            color: WhizzColors.secondary,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TypographySystem.bodyMedium.copyWith(
            color: WhizzColors.onSurfaceVariant,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: GoldenRatio.spacing20,
            vertical: GoldenRatio.spacing16,
          ),
        ),
      ),
    );
  }
}
