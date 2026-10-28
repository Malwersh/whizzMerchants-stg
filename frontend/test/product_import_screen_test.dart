import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/screens/product_import_screen.dart';

void main() {
  testWidgets('import screen explains preview safety and exposes CSV/XLSX choice', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProductImportScreen(businessId: 'branch-1'),
    ));
    expect(find.text('استيراد المنتجات'), findsOneWidget);
    expect(find.text('اختيار CSV أو XLSX'), findsOneWidget);
    expect(find.text('إضافة فقط'), findsOneWidget);
    expect(find.text('تحديث المحدد'), findsOneWidget);
    expect(find.textContaining('المعاينة لا تغيّر المنتجات الحية'), findsOneWidget);
    expect(find.text('فحص ومعاينة'), findsOneWidget);
  });
}
