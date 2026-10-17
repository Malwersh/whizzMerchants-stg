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
}
