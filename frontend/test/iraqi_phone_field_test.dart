import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/widgets/iraqi_phone_field.dart';

void main() {
  testWidgets(
      'branch phone accepts Iraqi local and international digits and rejects foreign numbers',
      (tester) async {
    final form = GlobalKey<FormState>(), controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Form(
                key: form, child: IraqiPhoneField(controller: controller)))));
    for (final input in ['', '07812345678', '+9647812345678', '٠٧٨١٢٣٤٥٦٧٨']) {
      controller.text = input;
      expect(form.currentState!.validate(), isTrue);
    }
    controller.text = '+15551234567';
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.textContaining('أدخل رقم هاتف عراقي'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
