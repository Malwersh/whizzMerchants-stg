import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whizz_merchants/models/order.dart';
import 'package:whizz_merchants/services/order_cache_service.dart';

void main() {
  test(
      'cancellation reference changes are detected even with identical status and timestamp',
      () async {
    SharedPreferences.setMockInitialValues({});
    Order make(Map<String, dynamic>? cancellation) => Order(
        id: 'c434',
        businessId: 'b',
        customerId: 'c',
        customerName: 'c',
        items: [],
        totalAmount: 5000,
        status: OrderStatus.preparing,
        createdAt: DateTime.utc(2026, 11, 4),
        updatedAt: DateTime.utc(2026, 11, 4),
        exceptionCancellation: cancellation);
    final original = make(null);
    await OrderCacheService.cacheOrder(original);
    expect(await OrderCacheService.hasOrderChanged(original), false);
    final pending = make({
      'requestId': 'CAN:r',
      'caseId': 'OEX:c',
      'state': 'REQUESTED',
      'version': 1
    });
    expect(await OrderCacheService.hasOrderChanged(pending), true);
    await OrderCacheService.cacheOrder(pending);
    expect(await OrderCacheService.hasOrderChanged(pending), false);
    expect(
        await OrderCacheService.hasOrderChanged(make({
          'requestId': 'CAN:r',
          'caseId': 'OEX:c',
          'state': 'CANCELLED',
          'version': 2
        })),
        true);
  });
}
