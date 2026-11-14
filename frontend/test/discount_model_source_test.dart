import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/models/discount.dart';

void main() {
  test(
      'reads actual stored merchant fields without replacing dates, title or usage',
      () {
    final value = Discount.fromJson({
      'discountId': 'discount-one',
      'businessId': 'branch-one',
      'title': 'عرض الغداء',
      'type': 'percentage',
      'value': 15,
      'description': 'اختبار',
      'status': 'active',
      'applicability': 'allItems',
      'valid_from': '2026-10-01T09:00:00.000Z',
      'valid_to': '2026-10-30T22:00:00.000Z',
      'minimum_order_amount': 3500,
      'usage_count': 7,
      'usage_limit': 20,
      'created_at': '2026-09-01T00:00:00.000Z',
      'updated_at': '2026-10-02T00:00:00.000Z',
    });
    expect(value.id, 'discount-one');
    expect(value.name, 'عرض الغداء');
    expect(value.startDate, DateTime.utc(2026, 10, 1, 9));
    expect(value.endDate, DateTime.utc(2026, 10, 30, 22));
    expect(value.currentUsage, 7);
    expect(value.maxUsage, 20);
    expect(value.minimumOrderAmount, 3500);
  });
  test('writes UTC millisecond dates accepted by commercial validation', () {
    final value = Discount.fromJson({
      'id': 'precision',
      'startDate': '2026-10-17T19:02:47.089811+03:00',
      'endDate': '2026-10-24T19:02:47.089811+03:00',
    });
    final json = value.toJson();
    expect(json['validFrom'], '2026-10-17T16:02:47.089Z');
    expect(json['validTo'], '2026-10-24T16:02:47.089Z');
    expect(json['startDate'], json['validFrom']);
    expect(json['endDate'], json['validTo']);
  });
  test('retains legacy camel case discount shapes', () {
    final value = Discount.fromJson({
      'id': 'old',
      'name': 'Legacy',
      'type': 'fixedAmount',
      'value': 1000,
      'startDate': '2026-10-01T00:00:00Z',
      'endDate': '2026-10-31T00:00:00Z',
      'currentUsage': 2,
      'maxUsage': 3,
      'minimumOrderAmount': 5000,
    });
    expect(value.id, 'old');
    expect(value.name, 'Legacy');
    expect(value.currentUsage, 2);
    expect(value.startDate, DateTime.utc(2026, 10, 1));
  });
  test('parses and emits the optional discount imageUrl', () {
    final withImage = Discount.fromJson({
      'id': 'img-1',
      'name': 'Image Discount',
      'type': 'percentage',
      'value': 10,
      'startDate': '2026-10-01T00:00:00Z',
      'endDate': '2026-10-31T00:00:00Z',
      'imageUrl': 'https://cdn.example.com/discounts/one.png',
    });
    expect(withImage.imageUrl,
        'https://cdn.example.com/discounts/one.png');
    expect(withImage.toJson()['imageUrl'],
        'https://cdn.example.com/discounts/one.png');

    // snake_case alias used by some consumers
    final aliased = Discount.fromJson({
      'id': 'img-2',
      'name': 'Image Discount 2',
      'type': 'percentage',
      'value': 15,
      'startDate': '2026-10-01T00:00:00Z',
      'endDate': '2026-10-31T00:00:00Z',
      'image_url': 'https://cdn.example.com/discounts/two.png',
    });
    expect(aliased.imageUrl, 'https://cdn.example.com/discounts/two.png');

    // Field stays null and is omitted from the payload when absent
    final noImage = Discount.fromJson({
      'id': 'img-3',
      'name': 'No Image',
      'type': 'percentage',
      'value': 20,
      'startDate': '2026-10-01T00:00:00Z',
      'endDate': '2026-10-31T00:00:00Z',
    });
    expect(noImage.imageUrl, isNull);
    expect(noImage.toJson().containsKey('imageUrl'), isFalse);

    // copyWith carries the value through
    final copied = noImage.copyWith(
        imageUrl: 'https://cdn.example.com/discounts/copied.png');
    expect(copied.imageUrl, 'https://cdn.example.com/discounts/copied.png');
  });
}
