import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/widgets/branch_options_editor.dart';
import 'package:whizz_merchants/models/product.dart';

void main() {
  testWidgets(
      'branch options retain IDs while names, prices and availability change',
      (tester) async {
    var value = <Map<String, dynamic>>[];
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, setState) => SingleChildScrollView(
                    child: Form(
                        key: form,
                        child: BranchOptionsEditor(
                            value: value,
                            onChanged: (v) => setState(() => value = v))))))));
    await tester.tap(find.text('Add option group'));
    await tester.pump();
    final groupId = value.single['id'];
    final optionId = value.single['options'][0]['id'];
    expect(form.currentState!.validate(), false);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Sides');
    await tester.enterText(fields.at(1), 'Salad');
    await tester.enterText(fields.at(2), '250');
    await tester.pump();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(value.single['id'], groupId);
    expect(value.single['required'], true);
    expect(value.single['options'][0]['id'], optionId);
    expect(value.single['options'][0]['extraPrice'], 250);
    expect(value.single['options'][0]['isAvailable'], false);
    expect(form.currentState!.validate(), true);
    await tester.enterText(fields.at(2), '-1');
    await tester.pump();
    expect(form.currentState!.validate(), false);
  });
  test('product serialization and unrelated edits retain branch option catalog',
      () {
    final groups = <Map<String, dynamic>>[
      {
        'id': 'sides',
        'title': 'Sides',
        'required': false,
        'maxSelections': 1,
        'options': [
          {
            'id': 'salad',
            'name': 'Salad',
            'extraPrice': 250,
            'isAvailable': true
          }
        ]
      }
    ];
    final product = Product(
        id: 'p',
        name: 'Meal',
        description: '',
        price: 1000,
        categoryId: 'cat',
        businessId: 'branch',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        optionGroups: groups);
    expect(Product.fromJson(product.toJson()).optionGroups, groups);
    expect(product.copyWith(price: 1250).optionGroups, groups);
  });
}
