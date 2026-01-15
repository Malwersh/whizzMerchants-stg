import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/app_logger.dart';
import '../models/order.dart';
import '../services/order_service.dart';

// Provider for pending orders
final pendingOrdersProvider =
    StateNotifierProvider<OrdersNotifier, List<Order>>((ref) {
  return OrdersNotifier();
});

// Provider for confirmed orders
final confirmedOrdersProvider =
    StateNotifierProvider<OrdersNotifier, List<Order>>((ref) {
  return OrdersNotifier();
});

// Provider for all orders
final allOrdersProvider =
    StateNotifierProvider<OrdersNotifier, List<Order>>((ref) {
  return OrdersNotifier();
});

class OrdersNotifier extends StateNotifier<List<Order>> {
  OrdersNotifier() : super([]);

  final OrderService _orderService = OrderService();

  Future<void> loadOrders(String businessId) async {
    try {
      final orders = await _orderService.getMerchantOrders(businessId);
      state = orders;
    } catch (e) {
      // Handle error
      AppLogger.error('Error loading orders: $e');

    }
  }

  void addOrder(Order order) {
    state = [...state, order];
  }

  void updateOrder(Order updatedOrder) {
    state = [
      for (final order in state)
        if (order.id == updatedOrder.id) updatedOrder else order,
    ];
  }

  void removeOrder(String orderId) {
    state = state.where((order) => order.id != orderId).toList();
  }

  void clearOrders() {
    state = [];
  }
}
