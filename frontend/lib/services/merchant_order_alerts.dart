import '../models/order.dart';
import 'dart:async';

class MerchantOrdersSnapshot {
  final String businessId;
  final List<Order> orders;
  MerchantOrdersSnapshot(this.businessId, List<Order> orders)
      : orders = List.unmodifiable(orders);
}

class MerchantOrderAlerts {
  static final _snapshots =
      StreamController<MerchantOrdersSnapshot>.broadcast(sync: true);
  static Stream<MerchantOrdersSnapshot> get snapshots => _snapshots.stream;
  static void publishSnapshot(String businessId, List<Order> orders) =>
      _snapshots.add(MerchantOrdersSnapshot(businessId, orders));
  static final _events = StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get events => _events.stream;
  static void receive(Map<String, dynamic> data) {
    final id = data['orderId']?.toString(),
        branch = data['businessId']?.toString() ?? data['storeId']?.toString();
    if (id != null && id.isNotEmpty && branch != null && branch.isNotEmpty)
      _events.add({'orderId': id, 'businessId': branch});
  }
}
