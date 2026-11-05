import 'package:flutter/material.dart';

import '../core/theme/whizz_colors.dart';

/// Shared, readable surfaces for the owner's branches and financial accounts.
class MerchantWorkspaceHeader extends StatelessWidget {
  const MerchantWorkspaceHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String title, subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFEDF2FA),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: WhizzColors.secondary, size: 28),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: WhizzColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: const Color(0xFF42526B), height: 1.6),
            ),
          ],
        ),
      );
}

class MerchantWorkspaceMessage extends StatelessWidget {
  const MerchantWorkspaceMessage({
    super.key,
    required this.message,
    this.isError = false,
    this.onRetry,
  });
  final String message;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isError ? Icons.cloud_off_outlined : Icons.storefront_outlined,
                color: WhizzColors.secondary,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: const Color(0xFF27364B), height: 1.6),
              ),
              if (onRetry != null)
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
            ],
          ),
        ),
      );
}

class MerchantBranchStatus extends StatelessWidget {
  const MerchantBranchStatus({super.key, required this.status});
  final String? status;
  @override
  Widget build(BuildContext context) {
    final normalized = status?.toLowerCase();
    final ready = normalized == 'active' || normalized == 'approved';
    final rejected = normalized == 'rejected' || normalized == 'suspended';
    final label = switch (normalized) {
      'active' => 'نشط',
      'approved' => 'معتمد',
      'rejected' => 'مرفوض',
      'suspended' => 'موقوف',
      'inactive' => 'غير نشط',
      'pending' || 'pending_approval' || null || '' => 'قيد المراجعة',
      _ => status!,
    };
    final foreground = ready
        ? const Color(0xFF16603D)
        : rejected
            ? const Color(0xFF9E2525)
            : const Color(0xFF795000);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ready
            ? const Color(0xFFE8F4ED)
            : rejected
                ? const Color(0xFFFCECEC)
                : const Color(0xFFFFF3D2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
