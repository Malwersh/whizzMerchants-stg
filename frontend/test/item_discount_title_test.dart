import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/models/item_discount_title.dart';

void main() {
  test('blank item sale name is generated without affecting its value', () {
    expect(
        itemDiscountTitle(
            customTitle: '  ', percentage: true, value: '20.0', itemCount: 1),
        'خصم 20٪ على وجبة');
    expect(
        itemDiscountTitle(
            customTitle: '', percentage: false, value: '500', itemCount: 3),
        'خصم 500 د.ع على 3 وجبات');
  });
  test('merchant custom title is preserved', () {
    expect(
        itemDiscountTitle(
            customTitle: ' عروض رمضان ',
            percentage: true,
            value: '15',
            itemCount: 2),
        'عروض رمضان');
  });
}
