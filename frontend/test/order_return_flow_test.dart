import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/models/order.dart';
import 'package:whizz_merchants/screens/order_cancellation_screen.dart';
import 'package:whizz_merchants/screens/order_return_screen.dart';
import 'package:whizz_merchants/services/order_returns_service.dart';

void main() {
  final selectors = {
    'businessId': 'branch1',
    'orderId': 'order1',
    'offerId': 'offer1',
    'attempt': 1
  };
  test(
      'return receipt transmits exact version and rejects stale session replies',
      () async {
    String? token = 'owner1';
    final service = OrderReturnsService(
        token: () async => token,
        client: MockClient((request) async {
          expect(request.url.path, endsWith('/auth/order-returns'));
          expect(request.body, contains('"expectedVersion":2'));
          expect(request.body, contains('"attempt":1'));
          token = 'other';
          return http.Response('{"success":true,"orderId":"order1"}', 200);
        }));
    await expectLater(service.call(selectors, receipt: {'expectedVersion': 2}),
        throwsException);
  });
  test('return states remain distinct from delivered and terminal returned',
      () {
    for (final entry in {
      'returning': OrderStatus.returning,
      'return_arrived': OrderStatus.returnArrived,
      'returned': OrderStatus.returned
    }.entries) {
      final order = Order.fromJson({
        'orderId': 'order1',
        'businessId': 'branch1',
        'items': [],
        'status': entry.key,
        'financialAssignment': {'offerId': 'offer1', 'attempt': 1}
      });
      expect(order.status, entry.value);
      expect(order.copyWith().financialAssignment?['attempt'], 1);
      expect(order.toJson()['financialAssignment'], isNotNull);
    }
  });
  testWidgets(
      'cancellation requires custody and no-cash declarations and explicit final confirmation',
      (tester) async {
    int calls = 0;
    final service = OrderReturnsService(
        token: () async => 'owner1',
        client: MockClient((r) async {
          calls++;
          expect(r.url.path, endsWith('/auth/order-cancellation'));
          expect(r.body, contains('"goodsRetainedByBranch":true'));
          return http.Response('{"success":true,"orderId":"order1"}', 200);
        }));
    await tester.pumpWidget(MaterialApp(
        home: OrderCancellationScreen(selectors: selectors, service: service)));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    for (final checkbox in find.byType(CheckboxListTile).evaluate().toList()) {
      await tester.tap(find.byWidget(checkbox.widget));
      await tester.pump();
    }
    await tester.tap(find.text('مراجعة الإلغاء'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('تأكيد الإلغاء'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('أكد الخادم إلغاء الطلب وتحرير الحجز'), findsOneWidget);
  });
  testWidgets(
      'owner receipt requires all explicit choices and sends the displayed case version',
      (tester) async {
    bool confirmed = false;
    int writes = 0;
    final service = OrderReturnsService(
        token: () async => 'owner1',
        client: MockClient((r) async {
          if (r.method == 'POST') {
            writes++;
            expect(r.body, contains('"expectedVersion":2'));
            expect(r.body, contains('"allItemsReceived":true'));
            confirmed = true;
            return http.Response('{"success":true,"orderId":"order1"}', 200);
          }
          return http.Response(
              '{"success":true,"orderId":"order1","returnId":"ret1","version":2,"status":"${confirmed ? 'CONFIRMED' : 'ARRIVED_AT_BRANCH'}"}',
              200);
        }));
    await tester.pumpWidget(MaterialApp(
        home: OrderReturnScreen(selectors: selectors, service: service)));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester
        .tap(find.byWidgetPredicate((w) => w is DropdownButtonFormField<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نعم، جميع الأصناف').last);
    await tester.pumpAndSettle();
    final fields =
        find.byWidgetPredicate((w) => w is DropdownButtonFormField<String>);
    await tester.tap(fields.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('سليمة').last);
    await tester.pumpAndSettle();
    await tester.tap(fields.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('لا توجد مسؤولية مسجلة').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.text('مراجعة وتأكيد الاستلام'));
    await tester.tap(find.text('مراجعة وتأكيد الاستلام'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.tap(find.text('تأكيد الإقرار'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('تم تأكيد الاستلام وانتهت العودة'), findsOneWidget);
  });
}
