import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/providers/product_provider_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('availability change omits unchanged legacy image and other fields', () async {
    SharedPreferences.setMockInitialValues({'business_id': 'branch'});
    FlutterSecureStorage.setMockInitialValues({'secure_id_token': 'test-token'});
    final provider = StateNotifierProvider<ProductNotifier, ProductState>(
      (ref) => ProductNotifier(ref, businessId: 'branch'),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final product = <String, dynamic>{
      'id': 'product', 'name': 'Food', 'description': '', 'price': 3000,
      'businessId': 'branch', 'categoryId': 'category', 'isAvailable': false,
      'imageUrl': 'https://example.com/product-images/product/legacy.png',
      'optionGroups': <dynamic>[],
    };
    var updates = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode({'products': [product]}), 200);
      }
      updates++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {'businessId', 'requestId', 'isAvailable'});
      expect(body['businessId'], 'branch');
      expect(body['isAvailable'], true);
      expect(body['requestId'], isNotEmpty);
      return http.Response(jsonEncode({'product': {...product, 'isAvailable': true}}), 200);
    });
    await http.runWithClient(() async {
      final notifier = container.read(provider.notifier);
      await notifier.loadProducts();
      final saved = container.read(provider).products.single;
      expect(await notifier.updateProduct(saved.copyWith(isAvailable: true)), true);
      expect(container.read(provider).products.single.isAvailable, true);
      expect(container.read(provider).products.single.imageUrls, [product['imageUrl']]);
      // Saving the unchanged editor must succeed without a second empty PUT.
      expect(await notifier.updateProduct(container.read(provider).products.single), true);
    }, () => client);
    expect(updates, 1);
  });
}
