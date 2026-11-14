import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/models/notification.dart';
import 'package:whizz_merchants/services/merchant_notification_inbox.dart';
import 'package:whizz_merchants/screens/merchant_notifications_screen.dart';

class FakeInbox extends MerchantNotificationInbox {
  FakeInbox() {
    items = [
      NotificationModel(
          id: 'one',
          title: 'طلب جديد',
          body: 'عميل',
          type: 'new_order',
          data: {},
          createdAt: DateTime.utc(2026, 10, 12)),
      NotificationModel(
          id: 'two',
          title: 'تحويل مكتمل',
          body: '5000 دينار',
          type: 'wallet_transfer_completed',
          data: {},
          isRead: true,
          createdAt: DateTime.utc(2026, 10, 11))
    ];
  }
  @override
  Future<void> load(String business) async {}
  @override
  Future<void> markRead({String? id}) async {
    items = items.map((x) => x.copyWith(isRead: true)).toList();
    notifyListeners();
  }
}

void main() {
  testWidgets('one list supports unread filter and marking all read',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MerchantNotificationsScreen(
            businessId: 'restaurant', service: FakeInbox())));
    await tester.pumpAndSettle();
    expect(find.text('طلب جديد'), findsOneWidget);
    expect(find.text('تحويل مكتمل'), findsOneWidget);
    await tester.tap(find.text('غير المقروءة'));
    await tester.pumpAndSettle();
    expect(find.text('تحويل مكتمل'), findsNothing);
    await tester.tap(find.text('قراءة الكل'));
    await tester.pumpAndSettle();
    expect(find.text('أنت مطّلع على كل جديد'), findsOneWidget);
  });
}
