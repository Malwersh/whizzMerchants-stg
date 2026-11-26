import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/services/merchant_enrollment_service.dart';

void main() {
  test('rejects staging and insecure enrollment endpoints', () {
    for (final url in [
      'https://example.com/staging',
      'http://example.com/production'
    ]) {
      expect(
          () => MerchantEnrollmentService(client: http.Client(), baseUrl: url),
          throwsArgumentError);
    }
  });
  test('verification binds the phone session, name and legal version',
      () async {
    final service = MerchantEnrollmentService(
      baseUrl: 'https://example.com/production',
      client: MockClient((r) async {
        expect(r.url.path, '/production/auth/merchant-enrollment/verify');
        expect(r.method, 'POST');
        final body = jsonDecode(r.body);
        expect(body['sessionId'], 'session');
        expect(body['legalAcceptance'], {'version': 'v1'});
        expect(body['legalAccepted'], true);
        expect(body.containsKey('password'), false);
        return http.Response(
            '{"username":"identity","loginProof":"proof"}', 200);
      }),
    );
    final result = await service.verify(
        phone: '+9647800868280',
        sessionId: 'session',
        code: '123456',
        name: 'Test Merchant',
        legalAcceptance: {'version': 'v1'});
    expect(result['username'], 'identity');
  });
  test('disabled enrollment fails without retrying or leaking response',
      () async {
    var calls = 0;
    final service = MerchantEnrollmentService(
        baseUrl: 'https://example.com/production',
        client: MockClient((_) async {
          calls++;
          return http.Response(
              '{"code":"ENROLLMENT_UNAVAILABLE","detail":"private"}', 503);
        }));
    await expectLater(
        service.send('+9647800868280'),
        throwsA(isA<MerchantEnrollmentException>()
            .having((e) => e.code, 'code', 'ENROLLMENT_UNAVAILABLE')
            .having(
                (e) => e.toString().contains('private'), 'no details', false)));
    expect(calls, 1);
  });
}
