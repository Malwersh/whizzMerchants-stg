import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/widgets/product_classifications_field.dart';
void main() {
 testWidgets('compact selector searches; cancellation preserves selection; confirm applies', (tester) async {
  List<String>? saved;
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: ProductClassificationsField(
   choices: const [{'id':'pizza','label':'بيتزا'},{'id':'burger','label':'برجر'}],
   selected: const ['pizza'], onChanged: (value) => saved = value))));
  expect(find.byType(CheckboxListTile), findsNothing);
  await tester.tap(find.text('تصنيفات المنتج — اختياري')); await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'برجر');await tester.pumpAndSettle();
  expect(find.byType(CheckboxListTile), findsOneWidget);
  await tester.tap(find.byType(CheckboxListTile));await tester.pump();
  await tester.tap(find.byTooltip('إغلاق'));await tester.pumpAndSettle();expect(saved,isNull);
  await tester.tap(find.text('تصنيفات المنتج — اختياري'));await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckboxListTile,'برجر'));await tester.pump();
  await tester.tap(find.text('اعتماد التصنيفات'));await tester.pumpAndSettle();
  expect(saved,['pizza','burger']);expect(tester.takeException(),isNull);
 });
}
