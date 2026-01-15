import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import '../providers/order_providers.dart'; // To invalidate order lists
import '../providers/session_provider.dart';
import 'order_service.dart';
import 'realtime_order_service.dart';

// Provider for the NotificationService
final notificationServiceProvider =
    ChangeNotifierProvider<NotificationService>((ref) {
  return NotificationService(ref);
});

/// Service for managing application notifications
class NotificationService extends ChangeNotifier {
  final Ref _ref;
  NotificationService(this._ref);

  final List<NotificationModel> _notifications = [];
  bool _enabled = true;
  bool _soundEnabled = true;

  List<NotificationModel> get notifications => List.unmodifiable(_notifications);
  bool get enabled => _enabled;
  bool get soundEnabled => _soundEnabled;

  /// Add a new notification
  void addNotification(NotificationModel notification) {
    _notifications.insert(0, notification); // Add at beginning for newest first
    notifyListeners();
    debugPrint('📧 Notification added: ${notification.title}');
  }

  /// Handles an action from a notification, like 'Accept' or 'Reject'
  Future<void> handleOrderAction(String orderId, String action) async {
    debugPrint('Handling action "$action" for order "$orderId"');
    try {
      final orderService = OrderService();
      final realtimeService = RealtimeOrderService();
      bool success = false;
      String? statusString;
      
      // Get businessId from session
      final session = _ref.read(sessionProvider);
      if (!session.isAuthenticated || session.businessId == null) {
        debugPrint('❌ No authenticated session or businessId found');
        return;
      }
      
      final businessId = session.businessId!;
      
      if (action == 'ACCEPT_ORDER') {
        await orderService.acceptMerchantOrder(orderId);
        success = true;
        statusString = 'confirmed';
      } else if (action == 'REJECT_ORDER') {
        await orderService.rejectMerchantOrder(orderId, businessId);
        success = true;
        statusString = 'cancelled';
      }

      if (success && statusString != null) {
        debugPrint(
            'Action "$action" for order "$orderId" was successful. Invalidating order providers.');
            
        // Send WebSocket notification to customers about order status update
        if (session.isAuthenticated && session.businessId != null) {
          debugPrint('📤 Sending order status update to customers: $orderId -> $statusString');
          realtimeService.sendOrderStatusUpdateToCustomers(
            orderId: orderId, 
            status: statusString,
            businessId: session.businessId!,
          );
        }
            
        // Invalidate providers to force a refresh of the order lists in the UI
        _ref.invalidate(pendingOrdersProvider);
        _ref.invalidate(confirmedOrdersProvider);
        _ref.invalidate(allOrdersProvider);

        // Optionally, remove the notification from the list now that it's handled
        _notifications.removeWhere((n) => n.data['orderId'] == orderId);
        notifyListeners();
      } else {
        debugPrint('Failed to handle action "$action" for order "$orderId"');
        // Optionally, show an error to the user
      }
    } catch (e) {
      debugPrint('Error handling order action: $e');
      // Optionally, show an error to the user
    }
  }

  /// Mark notification as read
  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  /// Mark all notifications as read
  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
  }

  /// Remove a notification
  void removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  /// Clear all notifications
  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }

  /// Clear all notifications (alias method)
  void clearAllNotifications() {
    clearAll();
  }

  /// Get unread count
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Enable/disable notifications
  void setEnabled(bool enabled) {
    _enabled = enabled;
    notifyListeners();
  }

  /// Enable/disable notification sounds
  void setSoundEnabled(bool soundEnabled) {
    _soundEnabled = soundEnabled;
    notifyListeners();
  }

  /// Add an order notification
  void addOrderNotification({
    required String title,
    required String body,
    String? orderId,
  }) {
    final notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: 'order',
      createdAt: DateTime.now(),
      data: orderId != null ? {'orderId': orderId} : {},
      businessId: 'default',
    );
    addNotification(notification);
  }

  /// Add a system notification
  void addSystemNotification({
    required String title,
    required String body,
  }) {
    final notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: 'system',
      createdAt: DateTime.now(),
      data: {},
      businessId: 'default',
    );
    addNotification(notification);
  }

  /// Connect to notifications (placeholder method)
  Future<void> connectToNotifications() async {
    debugPrint('📡 Connecting to notifications...');
    // Placeholder implementation
  }

  /// Send test notification
  Future<void> sendTestNotification() async {
    addSystemNotification(
      title: 'Test Notification',
      body: 'This is a test notification to verify the system is working.',
    );
  }

  /// Check if connected (placeholder)
  bool get isConnected => true;

  /// Notification stream (placeholder)
  Stream<NotificationModel> get notificationStream async* {
    // Placeholder stream implementation
  }
}
