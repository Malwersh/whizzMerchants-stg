import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/widgets/discount_funding_notice.dart';

void main() {
  Widget host(Widget child, {bool ar = false}) => MaterialApp(
    locale: Locale(ar ? 'ar' : 'en'), supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
  testWidgets('goods disclosure explains the default payer and renewed consent in both languages', (tester) async {
    for (final ar in [false, true]) {
      bool reviewed = false;
      await tester.pumpWidget(host(DiscountFundingNotice(editing: true, onReview: () => reviewed = true), ar: ar));
      await tester.pumpAndSettle();
      expect(find.textContaining(ar ? 'افتراضياً' : 'by default'), findsOneWidget);
      expect(find.textContaining(ar ? 'جدّد الموافقة' : 'renew sharing consent'), findsOneWidget);
      await tester.tap(find.text(ar ? 'مراجعة الاتفاقيات التجارية' : 'Review commercial agreements'));
      expect(reviewed, true);
    }
  });
  testWidgets('delivery disclosure requires separate approved funding and makes no goods payer claim', (tester) async {
    await tester.pumpWidget(host(const DiscountFundingNotice(delivery: true)));
    expect(find.textContaining('approved delivery funding policy'), findsOneWidget);
    expect(find.textContaining('merchant pays'), findsNothing);
    expect(find.textContaining('does not create'), findsWidgets);
  });
}
