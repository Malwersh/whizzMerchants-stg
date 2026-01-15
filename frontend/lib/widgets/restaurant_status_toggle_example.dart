// Example usage of real-time business status updates in business app
// This code can be integrated into the restaurant dashboard or status toggle component

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/websocket_service.dart';
import '../core/theme/whizz_colors.dart';

class RestaurantStatusToggle extends ConsumerStatefulWidget {
  final String businessId;
  final String userId;

  const RestaurantStatusToggle({
    super.key,
    required this.businessId,
    required this.userId,
  });

  @override
  ConsumerState<RestaurantStatusToggle> createState() => _RestaurantStatusToggleState();
}

class _RestaurantStatusToggleState extends ConsumerState<RestaurantStatusToggle> {
  bool _isBusy = false;
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final webSocketService = ref.watch(webSocketServiceProvider);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Restaurant Status',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isBusy ? Colors.red.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isBusy ? Colors.red.shade300 : Colors.green.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isBusy ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isBusy ? 'مشغول' : 'متاح',
                    style: TextStyle(
                      color: _isBusy ? Colors.red.shade700 : Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            if (_isBusy)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'العملاء سيرون أن المطعم مشغول ولا يمكن قبول طلبات جديدة حالياً',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Toggle button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUpdating ? null : _toggleBusyStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBusy ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: _isUpdating 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(_isBusy ? Icons.play_arrow : Icons.pause),
                label: Text(
                  _isUpdating 
                      ? 'جاري التحديث...'
                      : _isBusy 
                          ? 'تغيير إلى متاح'
                          : 'تغيير إلى مشغول',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleBusyStatus() async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final webSocketService = ref.read(webSocketServiceProvider);
      final newBusyStatus = !_isBusy;

      // Send the busy status update via WebSocket
      webSocketService.sendBusinessBusyStatusUpdate(
        businessId: widget.businessId,
        userId: widget.userId,
        isBusy: newBusyStatus,
      );

      // Update local state
      setState(() {
        _isBusy = newBusyStatus;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newBusyStatus 
                  ? 'تم تغيير حالة المطعم إلى مشغول'
                  : 'تم تغيير حالة المطعم إلى متاح',
              style: TextStyle(color: WhizzColors.secondary),
            ),
            backgroundColor: WhizzColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

    } catch (error) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث حالة المطعم: $error', style: TextStyle(color: WhizzColors.secondary)),
            backgroundColor: WhizzColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }
}

// Usage example in a dashboard or main screen:
/*
class RestaurantDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('لوحة تحكم المطعم'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Other dashboard widgets...
            
            RestaurantStatusToggle(
              businessId: 'your_business_id_here',
              userId: 'your_user_id_here',
            ),
            
            // More dashboard widgets...
          ],
        ),
      ),
    );
  }
}
*/
