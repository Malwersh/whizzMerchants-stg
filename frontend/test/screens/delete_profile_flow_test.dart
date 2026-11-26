import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/screens/delete_account_screen.dart';

void main() {
  Future<void> open(WidgetTester tester, String? businessId) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => openMerchantDeletion(context, businessId),
                    child: const Text('Open deletion'))))));
    await tester.tap(find.text('Open deletion'));
    await tester.pumpAndSettle();
  }

  testWidgets('Restaurant deletion and personal deletion are distinct choices',
      (tester) async {
    await open(tester, 'test-restaurant');
    expect(find.text('إغلاق وحذف المطعم'), findsOneWidget);
    expect(find.text('حذف حسابي الشخصي'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountScreen), findsNothing);
  });
  testWidgets('Without a restaurant only personal deletion is offered',
      (tester) async {
    await open(tester, null);
    expect(find.text('إغلاق وحذف المطعم'), findsNothing);
    expect(find.text('حذف حسابي الشخصي'), findsOneWidget);
  });
}
