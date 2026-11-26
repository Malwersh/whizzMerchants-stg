import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/l10n/app_localizations.dart';
import 'package:whizz_merchants/models/discount.dart';
import 'package:whizz_merchants/screens/discount_management_page.dart';

void main() {
  testWidgets('shared cards expose replacement and stop, with no edit or delete action', (tester) async {
    var replaced = 0;
    final discount = Discount.fromJson({
      'discountId': 'shared', 'title': 'خصم مشترك', 'businessId': 'branch',
      'type': 'fixedAmount', 'value': 500, 'status': 'active',
      'sharingLocked': true, 'revision': 'stored-revision',
      'valid_from': '2026-10-01T00:00:00Z', 'valid_to': '2099-10-01T00:00:00Z',
    });
    expect(discount.copyWith(name: 'name').sharingLocked, isTrue);
    expect(discount.copyWith(name: 'name').revision, 'stored-revision');
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'), supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: SingleChildScrollView(child: DiscountCard(discount: discount,
        onEdit: () => replaced++, onDelete: () => fail('Shared history must not be deleted'), onToggleStatus: () {}))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('إيقاف الخصم وإنشاء بديل'), findsOneWidget);
    expect(find.text('إيقاف الخصم'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    await tester.tap(find.text('إيقاف الخصم وإنشاء بديل'));
    expect(replaced, 1);
    expect(tester.takeException(), isNull);
  });
}
