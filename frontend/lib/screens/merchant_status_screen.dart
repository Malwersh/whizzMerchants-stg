import 'package:flutter/material.dart';
import '../core/design_system/design_system.dart';
import '../models/business.dart';
import '../services/app_auth_service.dart';
import 'auth/auth_screen.dart';

class MerchantStatusScreen extends StatelessWidget {
  final String status;
  final String? message;
  final Business? business;

  const MerchantStatusScreen({
    super.key,
    required this.status,
    this.message,
    this.business,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WhizzColors.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Modern Status Icon with enhanced design
                Container(
                  width: AppSpacing.xxxl * 1.5,
                  height: AppSpacing.xxxl * 1.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                  color: WhizzColors.grey100,
                  boxShadow: WhizzColors.elevation(3),
                  ),
                  child: Icon(
                    _getStatusIcon(),
                    size: AppSpacing.xxxl,
                    color: _getStatusColor(),
                  ),
                ),
                SizedBox(height: AppSpacing.xl + AppSpacing.xs),

                // Modern Status Title
                Text(
                  _getStatusTitle(context),
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: WhizzColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppSpacing.md),

                // Enhanced Status Message
                Container(
                  padding: EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                  color: WhizzColors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                    border: Border.all(
                    color: WhizzColors.borderLight,
                      width: 1,
                    ),
                  boxShadow: WhizzColors.elevation(2),
                  ),
                  child: Text(
                    message ?? _getDefaultMessage(context),
                    style: AppTypography.bodyLarge.copyWith(
                      color: WhizzColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: AppSpacing.xl + AppSpacing.md),

                // Modern Support Section
                _buildModernSupportSection(context),
              ],
            ),
          ),
      ),
    );
  }

  Widget _buildModernSupportSection(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: WhizzColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(
          color: WhizzColors.borderLight,
          width: 1,
        ),
        boxShadow: WhizzColors.elevation(2),
      ),
      child: Column(
        children: [
          Text(
            'Need Help?',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: WhizzColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Contact our support team if you have any questions.',
            style: AppTypography.bodyMedium.copyWith(
              color: WhizzColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => _navigateToLogin(context),
            style: TextButton.styleFrom(
              foregroundColor: WhizzColors.secondary,
              textStyle: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'approved':
        return WhizzColors.success;
      case 'pending':
        return WhizzColors.warning;
      case 'rejected':
        return WhizzColors.error;
      case 'suspended':
        return WhizzColors.error;
      default:
        return WhizzColors.textSecondary;
    }
  }

  IconData _getStatusIcon() {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'pending':
        return Icons.access_time;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'suspended':
        return Icons.warning_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusTitle(BuildContext context) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Account Approved';
      case 'pending':
        return 'Application Pending';
      case 'rejected':
        return 'Application Rejected';
      case 'suspended':
        return 'Account Suspended';
      default:
        return 'Unknown Status';
    }
  }

  String _getDefaultMessage(BuildContext context) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Your merchant account has been approved. You can now start using the platform.';
      case 'pending':
        return 'Your application is being reviewed. We will notify you once the review is complete.';
      case 'rejected':
        return 'Your application has been rejected. Please contact support for more information.';
      case 'suspended':
        return 'Your account has been suspended. Please contact support to resolve this issue.';
      default:
        return 'Unknown status detected. Please contact support.';
    }
  }

  void _navigateToLogin(BuildContext context) async {
    try {
      await AppAuthService.signOut();
    } catch (e) {
      // Handle error silently
    }
    
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );
    }
  }
}
