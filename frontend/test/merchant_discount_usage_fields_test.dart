import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/models/discount.dart';
import 'package:whizz_merchants/widgets/merchant_discount_usage_fields.dart';

void main() {
  test('wire contract keeps total and per-customer limits independent', () {
    final value = Discount.fromJson({'id': 'limits', 'usage_limit': 100, 'perCustomerLimit': 1, 'maxDiscountAmount': 1500});
    final json = value.toJson();
    expect(json['usageLimit'], 100);
    expect(json['perCustomerLimit'], 1);
    expect(json['maxDiscountAmount'], 1500);
    expect(value.copyWith(name: 'other').perCustomerLimit, 1);
    expect(Discount.fromJson({'id':'legacy'}).toJson()['perCustomerLimit'], isNull);
  });
  test('limits allow explicit unlimited blank, and reject zero, negatives, fractional or malformed counts', () {
    expect(MerchantDiscountUsageFields.parse('١٠٠'), 100);
    for (final input in ['', '1', '100', '١٠٠']) { expect(MerchantDiscountUsageFields.validate(input), isNull); }
    for (final input in ['0', '-1', '1.5', '1e3', 'abc']) { expect(MerchantDiscountUsageFields.validate(input), isNotNull); }
  });
  testWidgets('form shows distinct limits and validates them before saving', (tester) async {
    final total = TextEditingController(), customer = TextEditingController(), cap = TextEditingController();
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Form(key: form,
      child: MerchantDiscountUsageFields(total: total, customer: customer, cap: cap, percentage: true))))));
    expect(find.text('عدد الاستخدامات لكل زبون'), findsOneWidget);
    expect(find.text('إجمالي استخدامات العرض لجميع الزبائن'), findsOneWidget);
    customer.text = '1'; total.text = '100'; cap.text = '1500';
    expect(form.currentState!.validate(), isTrue);
    total.text = '0'; expect(form.currentState!.validate(), isFalse);
    expect(tester.takeException(), isNull);
  });
}
