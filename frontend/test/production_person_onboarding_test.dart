import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/services/merchant_enrollment_service.dart';
import 'package:whizz_merchants/services/person_onboarding_service.dart';
import 'package:whizz_merchants/services/production_person_onboarding_service.dart';

void main() {
  test('details are local; verify uses latest consent and exchanges proof once',
      () async {
    final requests = <http.Request>[];
    var exchanges = 0;
    final client = MockClient((r) async {
      requests.add(r);
      if (r.url.path.endsWith('/send'))
        return http.Response('{"sessionId":"s1"}', 200);
      if (r.url.path.endsWith('/verify')) {
        final b = jsonDecode(r.body);
        expect(b['name'], 'Test Owner');
        expect(b['legalAcceptance'], {'revision': 2});
        return http.Response('{"username":"uid","loginProof":"proof"}', 200);
      }
      expect(r.url.host, 'z6arovog63.execute-api.us-east-1.amazonaws.com');
      expect(r.headers['authorization'], 'token');
      return http.Response('{"profile":{"subjectId":"uid"}}', 200);
    });
    final api = ProductionPersonOnboardingService(
        client: client,
        headers: () async => {'Authorization': 'token'},
        exchangeProof: (u, p) async {
          expect(u, 'uid');
          expect(p, 'proof');
          exchanges++;
          return true;
        });
    final details = {
      'firstName': 'Test',
      'lastName': 'Owner',
      'phoneNumber': '+9647800868280',
      'legalAcceptance': {'revision': 1}
    };
    await api.call('person-registration', authenticated: false, body: details);
    expect(requests, isEmpty);
    await api.startPhoneSignIn('+9647800868280');
    await api.call('person-registration', authenticated: false, body: {
      ...details,
      'legalAcceptance': {'revision': 2}
    });
    expect(await api.verifyPhoneCode('123456'), true);
    await api.call('person-profile', body: {'legalAccepted': true});
    expect(requests.length, 3);
    expect(exchanges, 1);
  });
  test('wrong OTP never starts a signed-in session', () async {
    var exchanges = 0;
    final api = ProductionPersonOnboardingService(
        client: MockClient((r) async => r.url.path.endsWith('/send')
            ? http.Response('{"sessionId":"s1"}', 200)
            : http.Response('{"code":"INVALID_CODE"}', 400)),
        exchangeProof: (_, __) async {
          exchanges++;
          return true;
        });
    await api.call('person-registration', body: {
      'phoneNumber': '+9647800868280',
      'firstName': 'Test',
      'lastName': 'Owner',
      'legalAcceptance': {'revision': 1}
    });
    await api.startPhoneSignIn('+9647800868280');
    await expectLater(api.verifyPhoneCode('000000'),
        throwsA(isA<MerchantEnrollmentException>()));
    expect(exchanges, 0);
  });
  test('changed legal documents require consent again', () async {
    final api = ProductionPersonOnboardingService(
        client: MockClient((r) async => r.url.path.endsWith('/send')
            ? http.Response('{"sessionId":"s1"}', 200)
            : http.Response('{"code":"LEGAL_DOCUMENTS_CHANGED"}', 409)));
    await api.call('person-registration', body: {
      'phoneNumber': '+9647800868280',
      'firstName': 'Test',
      'lastName': 'Owner',
      'legalAcceptance': {'revision': 1}
    });
    await api.startPhoneSignIn('+9647800868280');
    await expectLater(api.verifyPhoneCode('000000'),
        throwsA(isA<LegalRegistrationException>()));
  });
}
