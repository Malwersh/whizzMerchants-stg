import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/app_logger.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import 'session_provider.dart';

// Provider for pending orders
final pendingOrdersProvider =
    StateNotifierProvider<OrdersNotifier, List<Order>>((ref) {
  return OrdersNotifier(
      businessId: ref.watch(sessionProvider).businessId ?? '');
});

// Provider for confirmed orders
final confirmedOrdersProvider =
    StateNotifierProvider<OrdersNotifier, List<Order>>((ref) {
  return OrdersNotifier(
      businessId: ref.watch(sessionProvider).businessId ?? '');
});

// Provider for all orders
final allOrdersProvider =
    StateNotifierProvider<OrdersNotifier, List<Order>>((ref) {
  return OrdersNotifier(
      businessId: ref.watch(sessionProvider).businessId ?? '');
});

class OrdersNotifier extends StateNotifier<List<Order>> {
  final String? businessId;
  final OrderService _orderService;
  int _request = 0;
  OrdersNotifier({this.businessId, OrderService? orderService})
      : _orderService = orderService ?? OrderService(),
        super([]);

  Future<void> loadOrders(String businessId) async {
    if (!mounted ||
        businessId.isEmpty ||
        (this.businessId != null && businessId != this.businessId)) return;
    final request = ++_request;
    state = [];
    try {
      final orders = await _orderService.getMerchantOrders(businessId);
      if (!mounted || request != _request) return;
      state = orders.where((order) => order.businessId == businessId).toList();
    } catch (e) {
      // Handle error
      AppLogger.error('Error loading orders: $e');
    }
  }

  void addOrder(Order order) {
    if (!mounted || (businessId != null && order.businessId != businessId))
      return;
    state = [...state, order];
  }

  void updateOrder(Order updatedOrder) {
    if (!mounted ||
        (businessId != null && updatedOrder.businessId != businessId)) return;
    state = [
      for (final order in state)
        if (order.id == updatedOrder.id) updatedOrder else order,
    ];
  }

  void removeOrder(String orderId) {
    state = state.where((order) => order.id != orderId).toList();
  }

  void clearOrders() {
    ++_request;
    if (mounted) state = [];
  }
}
