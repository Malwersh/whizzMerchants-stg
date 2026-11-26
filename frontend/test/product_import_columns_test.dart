import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/services/product_import_columns.dart';

void main() {
  test('Arabic Excel headers map fields without importing unknown vendor notes',
      () {
    final h = productImportHeaders(
        '\ufeffاسم الصنف,السعر,الكمية,اسم الصورة,ملاحظة\nبرغر,6000,2,a.jpg,تجاهل');
    final m = suggestProductImportMapping(h);
    expect(m, {
      'name': 'اسم الصنف',
      'price': 'السعر',
      'stock': 'الكمية',
      'imageFile': 'اسم الصورة'
    });
  });
  test(
      'quoted and BOM headers retain commas and cannot create duplicate assignments',
      () {
    final h = productImportHeaders(
        '\ufeff"product name",price,"notes, private"\r\na,1000,x');
    expect(h, ['product name', 'price', 'notes, private']);
    expect(suggestProductImportMapping(h),
        {'name': 'product name', 'price': 'price'});
  });
}
