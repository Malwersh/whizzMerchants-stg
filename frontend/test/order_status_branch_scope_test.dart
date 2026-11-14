import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../lib/services/order_service.dart';
import '../lib/core/exceptions/auth_exceptions.dart';

void main() {
  test('preparation and ready updates carry the selected branch', () async {
    final requests = <http.Request>[];
    final service = OrderService(tokenProvider: () async => 'test-token');
    await http.runWithClient(() async {
      for (final branch in ['first', 'second']) {
        for (final status in ['preparing', 'readyForPickup']) {
          await service.updateMerchantOrderStatus('order', status,
              businessId: branch);
        }
      }
    },
        () => MockClient((r) async {
              requests.add(r);
              return http.Response('{}', 200);
            }));
    expect(requests.map((r) => jsonDecode(r.body)), [
      {'status': 'preparing', 'businessId': 'first'},
      {'status': 'ready_for_pickup', 'businessId': 'first'},
      {'status': 'preparing', 'businessId': 'second'},
      {'status': 'ready_for_pickup', 'businessId': 'second'},
    ]);
  });
  test('missing branch fails before authentication or network', () async {
    final service =
        OrderService(tokenProvider: () async => throw StateError('unexpected'));
    await expectLater(
        service.updateMerchantOrderStatus('order', 'preparing', businessId: ''),
        throwsArgumentError);
  });
  test('permission denial is not reported as expired authentication', () async {
    final service = OrderService(tokenProvider: () async => 'test-token');
    for (final code in [401, 403]) {
      await http.runWithClient(() async {
        await expectLater(
            service.updateMerchantOrderStatus('order', 'preparing',
                businessId: 'branch'),
            throwsA(code == 401
                ? isA<AuthTokenExpiredException>()
                : predicate((e) =>
                    e is Exception &&
                    e is! AuthTokenExpiredException &&
                    e.toString().contains('صلاحية'))));
      }, () => MockClient((_) async => http.Response('{}', code)));
    }
  });
}
