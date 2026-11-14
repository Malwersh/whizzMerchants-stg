import 'package:flutter_test/flutter_test.dart';
import '../lib/models/order.dart';
import '../lib/services/branch_employee_access.dart';
import '../lib/services/branch_device_service.dart';

class EmployeeApi extends BranchDeviceService {
  final requests = <Map<String, dynamic>>[];
  bool reject = false;
  @override
  Future<Map<String, dynamic>> operation(String token, String path,
      {String? session, Map<String, dynamic>? body, String? method}) async {
    requests
        .add({'token': token, 'path': path, 'session': session, 'body': body});
    if (reject) throw BranchDeviceException('MEMBERSHIP_REVOKED');
    return {
      'orders': [
        {
          'orderId': 'o',
          'status': 'pending',
          'items': [],
          'totalAmount': 3500,
          'createdAt': '2026-10-15T00:00:00Z'
        }
      ]
    };
  }
}

void main() {
  test('original orders adapter uses only device and individual staff session',
      () async {
    final api = EmployeeApi();
    final access = BranchEmployeeAccess(
        api: api,
        token: 'device',
        session: 'staff',
        businessId: 'branch',
        profile: {},
        lock: () async {});
    expect((await access.orders()).single.businessId, 'branch');
    for (final status in [
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.readyForPickup,
      OrderStatus.cancelled
    ]) {
      await access.update('o', status, reason: 'نفدت الكمية');
    }
    expect(api.requests.map((r) => r['path']), [
      'merchant/orders/branch',
      'merchant/order/o/confirm',
      'merchant/order/o/status',
      'merchant/order/o/status',
      'merchant/order/o/reject'
    ]);
    expect(
        api.requests
            .every((r) => r['token'] == 'device' && r['session'] == 'staff'),
        true);
    expect(api.requests.last['body']['businessId'], 'branch');
    api.reject = true;
    await expectLater(access.update('o', OrderStatus.confirmed),
        throwsA(isA<BranchDeviceException>()));
    final count = api.requests.length;
    await expectLater(access.update('o', OrderStatus.delivered),
        throwsA(isA<BranchDeviceException>()));
    expect(api.requests.length, count);
  });
}
