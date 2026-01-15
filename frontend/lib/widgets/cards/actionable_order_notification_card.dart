import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../core/theme/whizz_colors.dart';

class ActionableOrderNotificationCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onViewDetails;
  final VoidCallback? onDismiss;

  const ActionableOrderNotificationCard({
    super.key,
    required this.order,
    this.onAccept,
    this.onReject,
    this.onViewDetails,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Order #${order.id}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close),
                    tooltip: 'Dismiss',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Total: ${(order.totalAmount / 1000).toStringAsFixed(0)} IQD'),
            Text('Items: ${order.items.length}'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (onAccept != null)
                  ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WhizzColors.success,
                      foregroundColor: WhizzColors.onPrimary,
                    ),
                    child: const Text('Accept'),
                  ),
                if (onReject != null)
                  ElevatedButton(
                    onPressed: onReject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WhizzColors.error,
                      foregroundColor: WhizzColors.onPrimary,
                    ),
                    child: const Text('Reject'),
                  ),
                if (onViewDetails != null)
                  ElevatedButton(
                    onPressed: onViewDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WhizzColors.info,
                      foregroundColor: WhizzColors.onPrimary,
                    ),
                    child: const Text('View Details'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
