import 'package:flutter/material.dart';
import '../../models/business.dart';
import '../../services/admin_service.dart';
import '../../services/app_auth_service.dart';
import 'package:whizz_merchants/core/design_system/design_system.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<List<Business>> _pendingBusinesses;
  final AdminService _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  void _initializeDashboard() async {
    try {
      final token = await AppAuthService.getAccessToken();
      if (token != null) {
        _pendingBusinesses = _adminService.getPendingBusinesses(token);
      }
    } catch (e) {
      // Handle error
    }
  }

  void _approveMerchant(String businessId) async {
    try {
      final token = await AppAuthService.getAccessToken();
      if (token != null) {
        await _adminService.approveMerchant(token, businessId);
        setState(() {
          _pendingBusinesses = _adminService.getPendingBusinesses(token);
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Merchant approved successfully'),
            ],
          ),
          backgroundColor: WhizzColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('Error approving merchant: $e')),
          ],
        ),
        backgroundColor: WhizzColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  void _rejectMerchant(String businessId) async {
    try {
      final token = await AppAuthService.getAccessToken();
      if (token != null) {
        await _adminService.rejectMerchant(token, businessId);
        setState(() {
          _pendingBusinesses = _adminService.getPendingBusinesses(token);
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
          content: Row(
            children: [
              Icon(Icons.cancel, color: Colors.white),
              const SizedBox(width: 8),
              Text('Merchant rejected successfully'),
            ],
          ),
          backgroundColor: WhizzColors.warning,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('Error rejecting merchant: $e')),
          ],
        ),
        backgroundColor: WhizzColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: WhizzColors.secondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.admin_panel_settings,
                size: 20,
                color: WhizzColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Admin Dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: WhizzColors.black,
        foregroundColor: WhizzColors.white,
        elevation: 0,
        actions: [
          Container(
            margin: EdgeInsets.only(right: AppSpacing.xs),
            decoration: BoxDecoration(
              color: WhizzColors.secondary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: WhizzColors.secondary,
              ),
              onPressed: () {
                setState(() {
                  _initializeDashboard();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.refresh, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Refreshing data...'),
                      ],
                    ),
                    backgroundColor: WhizzColors.info,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
      backgroundColor: WhizzColors.backgroundPrimary,
      body: FutureBuilder<List<Business>>(
          future: _pendingBusinesses,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      decoration: BoxDecoration(
                      color: WhizzColors.grey100,
                        borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: WhizzColors.borderLight),
                      ),
                      child: CircularProgressIndicator(
                        valueColor:
                          AlwaysStoppedAnimation<Color>(WhizzColors.black),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Loading pending businesses...',
                      style: TextStyle(
                        fontSize: 16,
                        color: WhizzColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Container(
                  margin: EdgeInsets.all(AppSpacing.xl),
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  decoration: BoxDecoration(
                    color: WhizzColors.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: WhizzColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: WhizzColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error Loading Data',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: WhizzColors.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(
                          color: WhizzColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _initializeDashboard();
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WhizzColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Container(
                  margin: EdgeInsets.all(AppSpacing.xl),
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  decoration: BoxDecoration(
                  color: WhizzColors.white,
                    borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: WhizzColors.borderLight),
                  boxShadow: WhizzColors.elevation(1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.business_center_outlined,
                        size: 64,
                      color: WhizzColors.grey400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Pending Businesses',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: WhizzColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All businesses have been processed.',
                        style: TextStyle(
                          color: WhizzColors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            } else {
              final businesses = snapshot.data!;
              return ListView.builder(
                padding: EdgeInsets.all(AppSpacing.md),
                itemCount: businesses.length,
                itemBuilder: (context, index) {
                  final business = businesses[index];
                  return Container(
                    margin: EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: WhizzColors.primary.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with business name and status
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: WhizzColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.business,
                                  color: WhizzColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      business.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            WhizzColors.warning.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: WhizzColors.warning
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        'Status: ${business.status}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: WhizzColors.warning,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Business details
                          if (business.email.isNotEmpty) ...[
                            _buildInfoRow(Icons.email, 'Email', business.email),
                            const SizedBox(height: 8),
                          ],
                          if (business.phone != null &&
                              business.phone!.isNotEmpty) ...[
                            _buildInfoRow(
                                Icons.phone, 'Phone', business.phone!),
                            const SizedBox(height: 8),
                          ],
                          if (business.address != null &&
                              business.address!.isNotEmpty) ...[
                            _buildInfoRow(Icons.location_on, 'Address',
                                business.address!),
                            const SizedBox(height: 16),
                          ],

                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _approveMerchant(business.id),
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text('Approve'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: WhizzColors.success,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _rejectMerchant(business.id),
                                  icon: const Icon(Icons.cancel),
                                  label: const Text('Reject'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: WhizzColors.error,
                                    side: BorderSide(color: WhizzColors.error),
                                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
          },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: WhizzColors.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: WhizzColors.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
