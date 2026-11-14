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
  static final _changes = <String>{};
  static bool isCancellation(Map<String, dynamic> d) => const {
        'customer_cancellation_requested',
        'order_cancellation_confirmed',
        'order_cancellation_updated'
      }.contains(d['action']);
  static void receive(Map<String, dynamic> data) {
    final id = data['orderId']?.toString(),
        branch = data['businessId']?.toString() ?? data['storeId']?.toString();
    if (id == null || id.isEmpty || branch == null || branch.isEmpty) return;
    if (isCancellation(data)) {
      final event = data['eventId']?.toString();
      if (event == null || event.isEmpty || !_changes.add('$branch:$event'))
        return;
      if (_changes.length > 500) _changes.remove(_changes.first);
    }
    _events.add({...data, 'orderId': id, 'businessId': branch});
  }
}
