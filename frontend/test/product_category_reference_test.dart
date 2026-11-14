import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/models/product.dart';

void main() {
  test('Arabic category reference wins over its English name', () {
    final category = ProductCategory.fromJson({
      'categoryId': 'real', 'name_ar': 'وجبات رئيسية', 'name': 'Main Dishes',
    });
    expect(category.id, 'real');
    expect(category.name, 'وجبات رئيسية');
  });
  test('legacy categoryName remains readable', () {
    expect(ProductCategory.fromJson({
      'categoryId': 'real', 'categoryName': 'حلويات',
      'categoryNameEn': 'Desserts',
    }).name, 'حلويات');
  });
}
