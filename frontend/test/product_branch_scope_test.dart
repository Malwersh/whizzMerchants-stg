import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/services/product_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({'business_id': 'stored-branch'});
    FlutterSecureStorage.setMockInitialValues({'secure_id_token': 'test-token'});
  });
  test('products use explicit open branch rather than stored branch', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['businessId'], 'open-branch');
      expect(request.headers['Authorization'], 'Bearer test-token');
      return http.Response(jsonEncode({'products': [{'productId':'p'}]}), 200);
    });
    final result = await http.runWithClient(
        () => ProductService.getProducts(businessId: 'open-branch'), () => client);
    expect(result['success'], true);
    expect(result['products'], hasLength(1));
  });
  test('other product callers retain stored branch scope', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['businessId'], 'stored-branch');
      return http.Response('{"products":[]}', 200);
    });
    expect((await http.runWithClient(() => ProductService.getProducts(), () => client))['success'], true);
  });
  test('forbidden branch does not refresh session or ask to log in', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('{"code":"OWNER_REQUIRED"}', 403);
    });
    final result = await http.runWithClient(
        () => ProductService.getProducts(businessId: 'foreign'), () => client);
    expect(requests, 1);
    expect(result['success'], false);
    expect(result['isAuthError'], false);
    expect(result['message'], contains('الفرع'));
  });
}
