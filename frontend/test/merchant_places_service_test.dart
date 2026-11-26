import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/services/merchant_places_service.dart';

void main() {
  test(
      'Iraqi search and chosen place share a session and return precise coordinates',
      () async {
    final requests = <Uri>[];
    final service = MerchantPlacesService(
        apiKey: 'fixture',
        client: MockClient((request) async {
          requests.add(request.url);
          return http.Response(
              jsonEncode(request.url.path.contains('autocomplete')
                  ? {
                      'status': 'OK',
                      'predictions': [
                        {'place_id': 'najaf', 'description': 'النجف، العراق'}
                      ]
                    }
                  : {
                      'status': 'OK',
                      'result': {
                        'formatted_address': 'النجف',
                        'geometry': {
                          'location': {'lat': 31.99, 'lng': 44.33}
                        }
                      }
                    }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    final results = await service.search('النجف');
    final point = await service.details(results.single.id);
    expect(requests.first.queryParameters['components'], 'country:iq');
    expect(requests.first.queryParameters['language'], 'ar');
    expect(requests[0].queryParameters['sessiontoken'],
        requests[1].queryParameters['sessiontoken']);
    expect(point.latitude, 31.99);
    expect(point.longitude, 44.33);
    await service.search('بغداد');
    expect(requests.last.queryParameters['sessiontoken'],
        isNot(requests.first.queryParameters['sessiontoken']));
    service.dispose();
  });
  test('Google denial is explicit rather than an empty successful search',
      () async {
    final service = MerchantPlacesService(
        apiKey: 'fixture',
        client: MockClient(
            (_) async => http.Response('{"status":"REQUEST_DENIED"}', 200)));
    await expectLater(service.search('النجف'), throwsException);
    service.dispose();
  });
}
