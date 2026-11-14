import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/models/order.dart';
import 'package:whizz_merchants/services/merchant_order_tabs.dart';
void main() {
  test('a ready order cannot appear in pending confirmed or preparing tabs', () {
    for(final status in [OrderStatus.readyForPickup,OrderStatus.assigned,OrderStatus.headingToCustomer]) {
      expect(merchantOrderMatchesFilter(status,'ready'),true);
      for(final tab in ['pending','confirmed','preparing','delivered'])expect(merchantOrderMatchesFilter(status,tab),false);
    }
  });
  test('each merchant transition removes the order from its former tab', () {
    final states={'pending':OrderStatus.pending,'confirmed':OrderStatus.confirmed,'preparing':OrderStatus.preparing,'ready':OrderStatus.readyForPickup};
    for(final current in states.entries)for(final tab in states.keys)expect(merchantOrderMatchesFilter(current.value,tab),tab==current.key);
  });
}
