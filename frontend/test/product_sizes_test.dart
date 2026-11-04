import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/widgets/product_sizes_sheet.dart';

void main() {
  test('final size prices retain existing additive pricing and identities', () {
    final result = buildProductSizes([
      {'id': 'small', 'name': 'صغير', 'price': 8000},
      {'id': 'large', 'name': 'كبير', 'price': 12000, 'isAvailable': false},
      {'id': 'medium', 'name': 'وسط', 'price': 10000},
    ], groupId: 'sizes');
    expect(result.basePrice, 8000);
    expect(result.group['id'], 'sizes');
    expect(result.group['required'], true);
    expect(result.group['maxSelections'], 1);
    final options = result.group['options'] as List;
    expect(options.map((o) => o['extraPrice']), [0, 4000, 2000]);
    expect(options[1]['id'], 'large');
    expect(options[1]['isAvailable'], false);
  });
  test('rejects duplicate sizes and invalid prices', () {
    for (final rows in [
      [
        {'name': 'صغير', 'price': 8000}
      ],
      [
        {'name': 'صغير', 'price': 8000},
        {'name': ' صغير ', 'price': 10000}
      ],
      [
        {'name': 'صغير', 'price': 0},
        {'name': 'كبير', 'price': 10000}
      ],
    ]) {
      expect(() => buildProductSizes(rows), throwsFormatException);
    }
  });
  testWidgets('size sheet applies final prices', (tester) async {
    ProductSizesResult? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result =
                          await showProductSizesSheet(context, basePrice: 8000);
                    },
                    child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final prices = find.widgetWithText(TextFormField, 'السعر الكامل (د.ع)');
    expect(prices, findsNWidgets(3));
    await tester.enterText(prices.at(1), '10000');
    await tester.enterText(prices.at(2), '12000');
    await tester.tap(find.text('اعتماد الأحجام والأسعار'));
    await tester.pumpAndSettle();
    expect(result?.basePrice, 8000);
    expect((result!.group['options'] as List).last['extraPrice'], 4000);
    expect(tester.takeException(), isNull);
  });
}
