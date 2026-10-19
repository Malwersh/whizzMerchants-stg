import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/models/order.dart';
import 'package:whizz_merchants/widgets/order_card.dart';

void main() {
  test('raw WizzOrders minor pricing displays IQD, including fractions', () {
    final order = Order.fromJson({
      'orderId': 'units',
      'pricing': {'total': 6250125, 'deliveryFee': 2500000},
      'items': [
        {'unitPrice': 3500000, 'quantity': 1}
      ],
    });
    expect(order.totalAmount, 6250.125);
    expect(order.deliveryFee, 2500);
    expect(order.items.single.price, 3500);
  });
  test('already converted API and cached IQD fields are not divided twice', () {
    final order = Order.fromJson({
      'orderId': 'units',
      'totalAmount': 6250,
      'deliveryFee': 2500,
      'pricing': {'total': 6250000, 'deliveryFee': 2500000},
      'items': [
        {'price': 3500, 'quantity': 1}
      ],
    });
    expect(order.totalAmount, 6250);
    expect(order.deliveryFee, 2500);
    expect(order.items.single.price, 3500);
  });
  test('zero direct fee and legacy high IQD total remain unchanged', () {
    final order = Order.fromJson({
      'orderId': 'units',
      'total': 2500000,
      'deliveryFee': 0,
      'pricing': {'deliveryFee': 2500000},
      'items': [],
    });
    expect(order.totalAmount, 2500000);
    expect(order.deliveryFee, 0);
  });
  test('order card displays already normalized IQD without a second division', () {
    final order = Order.fromJson({'orderId':'canary', 'pricing':{'total':9500000},
      'items':[{'unitPrice':3500000,'quantity':2}]});
    expect(formatOrderCardIqd(order.items.single.price * order.items.single.quantity), '7,000 د.ع');
    expect(formatOrderCardIqd(order.totalAmount), '9,500 د.ع');
    expect(formatOrderCardIqd(6250.125), '6,250.125 د.ع');
  });

}
