import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/models/order.dart';
import 'package:whizz_merchants/services/merchant_order_alerts.dart';

void main() {
  test('snapshots propagate empty-to-new-to-empty without a tab event',
      () async {
    final snapshots = <MerchantOrdersSnapshot>[];
    final subscription = MerchantOrderAlerts.snapshots.listen(snapshots.add);
    MerchantOrderAlerts.publishSnapshot('branchA', []);
    MerchantOrderAlerts.publishSnapshot('branchA', [
      Order.fromJson({'orderId': 'arriving', 'businessId': 'branchA'})
    ]);
    MerchantOrderAlerts.publishSnapshot('branchA', []);
    expect(snapshots.map((s) => s.businessId), everyElement('branchA'));
    expect(snapshots.map((s) => s.orders.length), [0, 1, 0]);
    expect(snapshots[1].orders.single.id, 'arriving');
    await subscription.cancel();
  });
  test('snapshots detach their list from subsequent caller mutations',
      () async {
    final values = <Order>[];
    final next = MerchantOrderAlerts.snapshots.first;
    MerchantOrderAlerts.publishSnapshot('branchB', values);
    values.add(Order.fromJson({'orderId': 'later'}));
    final snapshot = await next;
    expect(snapshot.businessId, 'branchB');
    expect(snapshot.orders, isEmpty);
    expect(() => snapshot.orders.clear(), throwsUnsupportedError);
  });
}
