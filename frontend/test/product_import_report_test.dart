import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/services/product_import_report.dart';

void main() {
  test(
      'error report includes rejected rows and neutralizes spreadsheet formulas',
      () {
    final csv = buildProductImportErrorCsv([
      {
        'rowId': '=cmd',
        'productId': 'p1',
        'name': '+منتج',
        'action': 'CREATE',
        'errors': ['INVALID_PRICE']
      },
      {'rowId': 'ok', 'errors': <String>[]},
    ]);
    expect(csv, startsWith('\ufeffrowId'));
    expect(csv, contains("'=cmd"));
    expect(csv, contains("'+منتج"));
    expect(csv, isNot(contains('\r\nok,')));
  });
}
