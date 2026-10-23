import 'dart:convert';
import 'dart:async';
import 'package:whizz_merchants/services/merchant_branch_scope.dart';
import 'package:whizz_merchants/providers/product_provider.dart';
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
  test('all product operations carry the selected branch; payload cannot override it', () async {
    final methods = <String>[];
    final client = MockClient((request) async {
      methods.add(request.method);
      expect(request.url.queryParameters['businessId'], 'stored-branch');
      if (['POST','PUT'].contains(request.method)) {
        expect(jsonDecode(request.body)['businessId'], 'stored-branch');
      }
      return http.Response('{"products":[],"product":{"productId":"p"},"categories":[]}', request.method == 'POST' ? 201 : 200);
    });
    await http.runWithClient(() async {
      await ProductService.createProduct(name:'p',description:'',price:1000,categoryId:'c',additionalData:{'businessId':'foreign'});
      await ProductService.updateProduct(productId:'p',price:1250,additionalData:{'businessId':'foreign'});
      await ProductService.deleteProduct('p');
      await ProductService.searchProducts('food');
      await ProductService.getProduct('p');
      await ProductService.searchGlobalCatalog('food');
      await ProductService.getAllCategories();
      await ProductService.getCategoriesForBusinessType('restaurant');
    }, () => client);
    expect(methods, ['POST','PUT','DELETE','GET','GET','GET','GET','GET']);
  });
  test('captured request scope stays stable across branch changes; new request uses new branch', () async {
    final first = await MerchantBranchScope.capture();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('business_id','second');
    final second = await MerchantBranchScope.capture();
    expect(first.businessId,'stored-branch');
    expect(second.businessId,'second');
    expect(first.body({'businessId':'foreign'})['businessId'],'stored-branch');
  });
  test('missing selection stops requests before network access', () async {
    SharedPreferences.setMockInitialValues({});
    var calls = 0;
    final client = MockClient((_) async { calls++; return http.Response('{}',200); });
    final result = await http.runWithClient(() => ProductService.getProducts(), () => client);
    expect(result['success'],false);
    expect(calls,0);
  });
  test('late product response does not update a disposed branch notifier', () async {
    final response = Completer<http.Response>();
    final notifier = ProductNotifier();
    final client = MockClient((_) => response.future);
    final pending = http.runWithClient(notifier.loadProducts, () => client);
    await Future<void>.delayed(const Duration(milliseconds:20));
    notifier.dispose();
    response.complete(http.Response('{"products":[]}',200));
    await pending;
  });

  test('branch notifier uses its captured branch even before session persistence catches up', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['businessId'],'new-branch');
      return http.Response('{"products":[]}',200);
    });
    final notifier=ProductNotifier(businessId:'new-branch');
    await http.runWithClient(notifier.loadProducts,()=>client);
    expect(notifier.state.error,isNull);
    notifier.dispose();
  });

}
