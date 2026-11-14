import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/services/onboarding_config_service.dart';

Map<String, dynamic> config(List types) => {
      'configVersion': 'policy-1',
      'version': 1,
      'termsVersion': 'terms-1',
      'termsTextAr': 'اتفاقية الاختبار',
      'types': types
    };
void main() {
  test('empty policy never opens hardcoded business types', () async {
    final service = OnboardingConfigService(client: MockClient((r) async {
      expect(r.url.queryParameters['regionId'], 'najaf');
      return http.Response(jsonEncode(config([])), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    expect((await service.load(regionId: 'najaf')).types, isEmpty);
    service.close();
  });
  test('centrally configured retail type needs no fixed business enum', () {
    final c = OnboardingConfig.fromJson(config([
      {
        'id': 'PERFUME',
        'model': 'RETAIL',
        'labelAr': 'عطور',
        'labelEn': 'Perfume',
        'fields': []
      }
    ]));
    expect(c.types.single['id'], 'PERFUME');
  });
  test('unavailable or malformed policy cannot imply successful registration',
      () async {
    final service = OnboardingConfigService(
        client: MockClient((_) async => http.Response('{}', 503)));
    await expectLater(service.load(), throwsException);
    expect(
        () => OnboardingConfig.fromJson({'types': []}), throwsFormatException);
    service.close();
  });
}
