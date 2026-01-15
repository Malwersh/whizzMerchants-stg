import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import 'realtime_order_service.dart';
import '../widgets/cards/actionable_order_notification_card.dart';
import 'dart:async';

final floatingOrderNotificationServiceProvider =
    Provider<FloatingOrderNotificationService>((ref) {
  return FloatingOrderNotificationService(ref);
});

class FloatingOrderNotificationService {
  final Ref _ref;
  OverlayEntry? _overlayEntry;
  BuildContext? _context;
  StreamSubscription? _newOrderSubscription;

  FloatingOrderNotificationService(this._ref) {
    _setupRealtimeOrderListener();
  }

  void initialize(BuildContext context) {
    _context = context;
  }

  void _setupRealtimeOrderListener() {
    _newOrderSubscription?.cancel();
    _newOrderSubscription =
        _ref.read(realtimeOrderServiceProvider).newOrderStream.listen((order) {
      debugPrint(
          '🔔 FloatingOrderNotificationService: New order received ${order.id}');
      if (_context != null) {
        _showActionableOrderNotification(order);
      }
    });
  }

  void _showActionableOrderNotification(Order order) {
    _overlayEntry?.remove();
    
    // Note: Sound is already played by RealtimeOrderService to avoid duplication
    // Only show the visual popup here
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: ActionableOrderNotificationCard(
            order: order,
            onDismiss: () {
              _overlayEntry?.remove();
              _overlayEntry = null;
            },
          ),
        ),
      ),
    );

    if (_context != null && _context!.mounted) {
      Overlay.of(_context!).insert(_overlayEntry!);
    }

    // Automatically remove the notification after a delay
    Future.delayed(const Duration(seconds: 15), () {
      if (_overlayEntry != null) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  void dispose() {
    _newOrderSubscription?.cancel();
    _overlayEntry?.remove();
  }
}
