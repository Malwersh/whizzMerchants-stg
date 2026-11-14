import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/services/account_deletion_service.dart';

String token(String sub) => 'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': sub, 'exp': 4102444800}))).replaceAll('=', '')}.signature';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({
    'secure_access_token': token('member'),
    'MEMBERSHIP:store': jsonEncode({'ownerId': 'member', 'token': 'receipt-capability'}),
  }));
  test('network loss preserves the saved receipt and does not return completed status', () async {
    final service = AccountDeletionService(scope: 'MEMBERSHIP', businessId: 'store', client: MockClient((_) async => throw const SocketException('offline')));
    await expectLater(service.call('status', followReceipt: true), throwsA(isA<SocketException>()));
    expect(await const FlutterSecureStorage().read(key: 'MEMBERSHIP:store'), contains('receipt-capability'));
    service.close();
  });
  test('server outage does not masquerade as deletion or logout', () async {
    final service = AccountDeletionService(scope: 'MEMBERSHIP', businessId: 'store', client: MockClient((_) async => http.Response('{"message":"temporarily unavailable"}', 503)));
    await expectLater(service.call('status', followReceipt: true), throwsException);
    expect(await const FlutterSecureStorage().read(key: 'secure_access_token'), token('member'));
    service.close();
  });
  test('completed membership receipt remains readable after its active pointer is removed', () async {
    final calls = <String>[];
    final service = AccountDeletionService(scope: 'MEMBERSHIP', businessId: 'store', client: MockClient((request) async {
      calls.add(request.url.path);
      if (request.method == 'GET') return http.Response('{"request":null}', 200);
      expect(jsonDecode(request.body)['receiptToken'], 'receipt-capability');
      return http.Response('{"request":{"status":"COMPLETED"}}', 200);
    }));
    expect((await service.call('status', followReceipt: true))['request']['status'], 'COMPLETED');
    expect(calls.length, 2);
    service.close();
  });
  test('a new leave request does not revive the previous completed membership receipt', () async {
    var calls = 0;
    final service = AccountDeletionService(scope: 'MEMBERSHIP', businessId: 'store', client: MockClient((_) async {calls++;return http.Response('{"request":null}', 200);}));
    expect((await service.call('status'))['request'], isNull);
    expect(calls, 1);
    service.close();
  });
  test('a different signed-in person cannot follow another person receipt', () async {
    FlutterSecureStorage.setMockInitialValues({'secure_access_token': token('other'), 'MEMBERSHIP:store': jsonEncode({'ownerId': 'member', 'token': 'receipt-capability'})});
    var calls = 0;
    final service = AccountDeletionService(scope: 'MEMBERSHIP', businessId: 'store', client: MockClient((_) async {calls++;return http.Response('{}', 401);}));
    await expectLater(service.call('status'), throwsException);
    expect(calls, 1);
    service.close();
  });
}
