import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/models/product.dart';
import 'package:whizz_merchants/services/product_update_patch.dart';
import 'package:whizz_merchants/services/product_import_template.dart';
import 'package:whizz_merchants/services/xlsx_csv_decoder.dart';

void main() {
  final before = Product.fromJson({
    'productId': 'p',
    'name': 'وجبة',
    'price': 3000,
    'categoryId': 'old',
    'imageUrl': 'https://legacy.example/burger.jpg',
    'isAvailable': true
  });
  test('availability edit does not resend legacy image or category', () {
    expect(productUpdatePatch(before, before.copyWith(isAvailable: false)),
        {'isAvailable': false});
  });
  test('price and name edit preserves untouched data', () {
    expect(
        productUpdatePatch(
            before, before.copyWith(price: 4000, name: 'وجبة جديدة')),
        {'price': 4000.0, 'name': 'وجبة جديدة'});
    expect(productUpdatePatch(before, before.copyWith()), isEmpty);
  });
  test('downloaded Excel template round trips through real importer', () {
    final csv = xlsxToCsv(productTemplateXlsx('c1'));
    expect(csv, contains('name,price,categoryId,description,imageFile,stock'));
    expect(csv, contains('برغر كلاسيك,6000,c1,وصف اختياري'));
    expect(csv, isNot(contains('burger.jpg')));
  });
}
