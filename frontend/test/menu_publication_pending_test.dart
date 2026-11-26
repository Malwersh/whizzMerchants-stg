import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/services/product_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'retry state persists only on failed publication and is isolated by branch',
      () async {
    expect(await ProductService.hasPendingPublication('a'), false);
    await ProductService.recordPublication('a', {'status': 'pending'});
    expect(await ProductService.hasPendingPublication('a'), true);
    expect(await ProductService.hasPendingPublication('b'), false);
    await ProductService.recordPublication('a', null);
    expect(await ProductService.hasPendingPublication('a'), true);
    await ProductService.recordPublication('a', {'status': 'published'});
    expect(await ProductService.hasPendingPublication('a'), false);
  });
}
