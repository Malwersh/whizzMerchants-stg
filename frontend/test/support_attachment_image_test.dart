import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/widgets/support_attachment_image.dart';

void main() {
  testWidgets(
      'private image loader handles immediate auth failure and retry without setState Future error',
      (tester) async {
    var calls = 0;
    Future<Uint8List> load() async {
      calls++;
      throw StateError('expired');
    }

    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SupportAttachmentImage(load: load))));
    expect(calls, 0);
    await tester.tap(find.text('عرض الصورة'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('تعذر تحميل الصورة؛ إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });
}
