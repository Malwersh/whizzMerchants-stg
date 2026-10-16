import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/models/order.dart';

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
}
