import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../lib/config/app_config.dart';
import '../lib/config/merchant_auth_routes.dart';
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
  test('production routes device orders to the isolated order service', () async {
    final requests = <http.Request>[];
    final api = BranchDeviceService(client: MockClient((request) async {
      requests.add(request);
      return http.Response('{"orders":[]}', 200);
    }));
    await api.operation('paired-device', 'merchant/orders/branch');
    await api.operation('paired-device', 'merchant/order/order/status',
        session: 'staff', body: {'businessId': 'branch', 'status': 'ready'});
    await expectLater(api.operation('paired-device', 'merchant/menu/branch'),
        throwsA(isA<BranchDeviceException>()));
    expect(requests.map((request) => request.url.toString()), [
      '${MerchantAuthRoutes.branchOrdersBase}/branch-device/merchant/orders/branch',
      '${MerchantAuthRoutes.branchOrdersBase}/branch-device/merchant/order/order/status',
    ]);
    expect(requests.map((request) => request.method), ['GET', 'PUT']);
    expect(requests.first.headers['x-staff-session'], isNull);
    expect(requests.last.headers['x-staff-session'], 'staff');
    expect(requests.last.headers['authorization'], 'Bearer paired-device');
  }, skip: !AppConfig.isProduction);

  test('production registers branch push with paired credentials only', () async {
    late http.Request sent;
    final api = BranchDeviceService(client: MockClient((request) async {
      sent = request;
      return http.Response('{"success":true}', 200);
    }));
    await api.call('pairing-credential', {
      'action': 'register_push',
      'businessId': 'branch',
      'pushToken': 'notifications-token',
      'platform': 'ios',
      'soundEnabled': true,
      'soundReady': <String>[],
    });
    expect(sent.url.toString(),
        '${MerchantAuthRoutes.branchOrderPushBase}/branch-device/push');
    expect(sent.headers['authorization'], 'Bearer pairing-credential');
    expect(sent.headers['x-staff-session'], isNull);
    expect(sent.body, contains('"businessId":"branch"'));
  }, skip: !AppConfig.isProduction);
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
