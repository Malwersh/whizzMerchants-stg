import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whizz_merchants/models/order.dart';
import 'package:whizz_merchants/services/merchant_notification_inbox.dart';

Order order(String id, String business) => Order(
    id: id,
    businessId: business,
    customerId: 'customer',
    customerName: 'عميل',
    items: [],
    totalAmount: 5000,
    status: OrderStatus.pending,
    createdAt: DateTime.utc(2026, 10, 12));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'history only includes the requested restaurant and does not create unread alerts',
      () async {
    final inbox = MerchantNotificationInbox(
        sharingLoader: (_) async => [],
        subjectLoader: () async => 'owner',
        orderLoader: (_) async =>
            [order('one', 'restaurant'), order('other', 'elsewhere')]);
    await inbox.load('restaurant');
    expect(inbox.items.length, 1);
    expect(inbox.items.single.orderId, 'one');
    expect(inbox.items.single.isRead, isTrue);
  });
  test(
      'read state survives refreshing and is isolated by account and restaurant',
      () async {
    final prefs = await SharedPreferences.getInstance();
    // Seed an actual received event independently of the backfill loader.
    await prefs.setString('merchant_inbox_owner_restaurant',
        '[{"id":"push","title":"طلب جديد","body":"","type":"new_order","data":{},"isRead":false,"businessId":"restaurant","createdAt":"2026-10-12T00:00:00Z"}]');
    String? account = 'owner';
    final inbox = MerchantNotificationInbox(
        sharingLoader: (_) async => [],
        subjectLoader: () async => account, orderLoader: (_) async => []);
    await inbox.load('restaurant');
    expect(inbox.items.single.isRead, isFalse);
    await inbox.markRead();
    await inbox.load('restaurant');
    expect(inbox.items.single.isRead, isTrue);
    await inbox.load('another');
    expect(inbox.items, isEmpty);
    account = 'different';
    await inbox.load('restaurant');
    expect(inbox.items, isEmpty);
    account = null;
    await inbox.load('restaurant');
    expect(inbox.items, isEmpty);
    expect(inbox.error, isNotNull);
  });
}
