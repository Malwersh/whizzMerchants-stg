import 'package:whizz_merchants/services/order_print_service.dart';
import 'package:whizz_merchants/services/kitchen_dispatch_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whizz_merchants/models/order.dart';
import 'package:whizz_merchants/screens/order_print_screen.dart';

void main() {
  testWidgets(
      'receipt preview switches kitchen/customer without requiring a printer',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final order = Order(
        id: 'preview',
        businessId: 'b',
        customerId: 'c',
        customerName: 'زبون',
        items: [
          OrderItem(id: 'p', name: 'بيتزا كبيرة', price: 8000, quantity: 1)
        ],
        totalAmount: 10000,
        deliveryFee: 2000,
        status: OrderStatus.confirmed,
        createdAt: DateTime(2026));
    await tester.pumpWidget(MaterialApp(
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: OrderPrintScreen(order: order))));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(find.text('معاينة فقط — لا تحتاج إلى طابعة'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('الزبون'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      for (final width in [384, 576]) {
        final png = await KitchenDispatchService.previewBytes(
            order, width, OrderPrintService.lines(order, 'customer'));
        expect(png.take(4), [137, 80, 78, 71]);
      }
    });
  });
}
