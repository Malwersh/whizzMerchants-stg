// Explicit staging-only operator smoke harness. Reuses the signed-in simulator session;
// never writes, prints or exports a token. Requires a temporary hidden branch owned by that session.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../lib/config/app_config.dart';
import '../lib/services/app_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validateOrThrow();
  runApp(const MaterialApp(
      home:
          Scaffold(body: Center(child: Text('اختبار المنتجات على staging…')))));
  final branch = const String.fromEnvironment('PRODUCTS_TEST_BRANCH');
  final result = <String, dynamic>{'branchId': branch, 'checks': <String>[]};
  try {
    if (AppConfig.environment != 'staging' ||
        !branch.startsWith('uatproducts336_'))
      throw StateError('ISOLATED_STAGING_BRANCH_REQUIRED');
    final token = await AppAuthService.getAccessToken();
    if (token == null) throw StateError('SIMULATOR_LOGIN_REQUIRED');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json'
    };
    Future<Map<String, dynamic>> call(String path,
        {Map<String, dynamic>? body, String method = 'GET'}) async {
      final uri = Uri.parse('${AppConfig.baseUrl}$path')
          .replace(queryParameters: {'businessId': branch});
      final response = method == 'GET'
          ? await http.get(uri, headers: headers)
          : await http.post(uri,
              headers: headers,
              body: jsonEncode({...?body, 'businessId': branch}));
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw StateError(
            '$method $path ${response.statusCode}: ${response.body}');
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    final baseline = (await call('/menu/versions/publish',
        method: 'POST',
        body: {'requestId': const Uuid().v4()}))['active'] as Map;
    final category = (await call('/categories', method: 'POST', body: {
      'requestId': const Uuid().v4(),
      'name': 'قسم اختبار الاستيراد 336'
    }))['category'] as Map;
    result['categoryId'] = category['categoryId'];
    (result['checks'] as List)
        .add('authenticated baseline publication and branch category creation');
    final photo = img.encodeJpg(img.Image(width: 16, height: 16));
    final uploaded = await call('/upload/product-image',
        method: 'POST',
        body: {'image': 'data:image/jpeg;base64,${base64Encode(photo)}'});
    final imageUrl = uploaded['imageUrl'] as String;
    result['imageUrl'] = imageUrl;
    final imageResponse = await http.get(Uri.parse(imageUrl));
    if (imageResponse.statusCode != 200)
      throw StateError('UPLOADED_IMAGE_NOT_READABLE');
    (result['checks'] as List).add(
        'authenticated JPEG upload, branch ownership and public image read');
    final file = [
      'اسم الصنف,السعر,الكمية,الصورة,تجاهل',
      ...List.generate(
          8, (i) => 'طبق اختبار $i,1500,${i == 0 ? 1 : 3},sample.jpg,x')
    ].join('\n');
    var job = (await call('/products/imports/preview', method: 'POST', body: {
      'format': 'CSV',
      'mode': 'ADD_ONLY',
      'csv': file,
      'columnMapping': {
        'name': 'اسم الصنف',
        'price': 'السعر',
        'stock': 'الكمية',
        'imageFile': 'الصورة'
      },
      'defaultCategoryId': category['categoryId'],
      'images': {'sample.jpg': imageUrl}
    }))['job'] as Map<String, dynamic>;
    if (job['counts']['valid'] != 8) throw StateError('INVALID_PREVIEW_ROWS');
    result['productIds'] =
        (job['rows'] as List).map((r) => r['productId']).toList();
    final ids = (job['rows'] as List).map((r) => r['rowId']).toList();
    final jobId = job['jobId'];
    job = (await call('/products/imports/$jobId/commit', method: 'POST', body: {
      'selectedRowIds': ids,
      'expectedVersion': job['version'],
      'offset': 0
    }))['job'] as Map<String, dynamic>;
    if (job['status'] != 'APPLYING' || job['nextOffset'] != 6)
      throw StateError('BATCH_NOT_RESUMABLE');
    job =
        (await call('/products/imports/$jobId'))['job'] as Map<String, dynamic>;
    job = (await call('/products/imports/$jobId/commit', method: 'POST', body: {
      'selectedRowIds': ids,
      'expectedVersion': job['version'],
      'offset': job['nextOffset']
    }))['job'] as Map<String, dynamic>;
    if (job['status'] != 'COMPLETED' || job['counts']['applied'] != 8)
      throw StateError('IMPORT_NOT_COMPLETE');
    (result['checks'] as List)
        .add('actual API column mapping, images and stock; two-batch resume');
    final published = (await call('/menu/versions/publish',
        method: 'POST',
        body: {'requestId': const Uuid().v4()}))['active'] as Map;
    if (published['productCount'] != 8)
      throw StateError('PUBLICATION_INCOMPLETE');
    (result['checks'] as List)
        .add('actual API immutable publication of all products');
    final productId = (result['productIds'] as List)[1];
    await call('/products/inventory', method: 'POST', body: {
      'productId': productId,
      'stock': 5,
      'expectedStock': 3,
      'requestId': const Uuid().v4()
    });
    final products = (await call('/products'))['products'] as List;
    if (products.firstWhere((p) => p['productId'] == productId)['stock'] != 5)
      throw StateError('STOCK_ADJUSTMENT_MISSING');
    await call('/products/inventory');
    (result['checks'] as List)
        .add('authenticated inventory quantity adjustment and review list');
    await call('/menu/versions/rollback', method: 'POST', body: {
      'requestId': const Uuid().v4(),
      'version': baseline['publishedVersion']
    });
    await call('/menu/versions/rollback', method: 'POST', body: {
      'requestId': const Uuid().v4(),
      'version': published['publishedVersion']
    });
    (result['checks'] as List).add(
        'actual API rollback and republish without changing current quantities');
    result['status'] = 'PASS';
  } catch (e) {
    result['status'] = 'FAIL';
    result['error'] = e.toString();
  }
  final dir = await getApplicationDocumentsDirectory();
  await File('${dir.path}/products-336-smoke.json')
      .writeAsString(const JsonEncoder.withIndent('  ').convert(result));
  runApp(MaterialApp(
      home: Scaffold(
          body: Center(
              child: Text(result['status'] == 'PASS'
                  ? 'نجح اختبار المنتجات'
                  : 'تعذر إكمال الاختبار؛ التفاصيل محفوظة محليًا')))));
}
