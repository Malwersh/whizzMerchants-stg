import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/l10n/app_localizations.dart';
import 'package:whizz_merchants/models/discount.dart';
import 'package:whizz_merchants/widgets/merchant_discount_value_fields.dart';

Widget app(TextEditingController controller,
    {double scale = 1, DiscountType initial = DiscountType.percentage}) {
  var type = initial;
  return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Builder(
          builder: (context) => Scaffold(
              body: Center(
                  child: TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (routeContext) =>
                              arabicMerchantDiscountContent(
                                  routeContext,
                                  (context) => SingleChildScrollView(
                                      child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: StatefulBuilder(
                                              builder: (context, setState) =>
                                                  Form(
                                                      child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                        Text(AppLocalizations
                                                                .of(context)!
                                                            .createDiscount),
                                                        Text(AppLocalizations
                                                                .of(context)!
                                                            .basicInformation),
                                                        MerchantDiscountValueFields(
                                                            type: type,
                                                            controller:
                                                                controller,
                                                            onTypeChanged:
                                                                (value) =>
                                                                    setState(
                                                                        () {
                                                                      type =
                                                                          value;
                                                                      controller
                                                                          .text = value ==
                                                                              DiscountType.percentage
                                                                          ? '10'
                                                                          : value == DiscountType.fixedAmount
                                                                              ? ''
                                                                              : '0';
                                                                    })),
                                                        Text(AppLocalizations
                                                                .of(context)!
                                                            .discountApplicability),
                                                        Text(
                                                            AppLocalizations.of(
                                                                    context)!
                                                                .allItems)
                                                      ]))))))),
                      child: const Text('فتح النموذج'))))));
}

void main() {
  testWidgets('Arabic editor overrides an English app and remains RTL',
      (tester) async {
    final c = TextEditingController(text: '10');
    addTearDown(c.dispose);
    await tester.pumpWidget(app(c));
    await tester.tap(find.text('فتح النموذج'));
    await tester.pumpAndSettle();
    for (final label in [
      'إنشاء خصم',
      'معلومات العرض',
      'الأصناف المشمولة بالخصم',
      'جميع الأصناف'
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Create Discount'), findsNothing);
    expect(
        Directionality.of(
            tester.element(find.byType(MerchantDiscountValueFields))),
        TextDirection.rtl);
  });
  for (final width in [320.0, 390.0, 600.0]) {
    testWidgets(
        'percentage and fixed amount fit width $width with enlarged Arabic text',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = TextEditingController(text: '10');
      addTearDown(c.dispose);
      await tester.pumpWidget(app(c, scale: 1.3));
      await tester.tap(find.text('فتح النموذج'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(DropdownButtonFormField<DiscountType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مبلغ ثابت').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discount-percentage')), findsNothing);
      expect(
          find.byKey(const ValueKey('discount-fixed-amount')), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '500');
      expect(c.text, '500');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'invalid fixed amounts are rejected without losing the valid amount',
      (tester) async {
    final c = TextEditingController(text: '0');
    addTearDown(c.dispose);
    await tester.pumpWidget(app(c, initial: DiscountType.fixedAmount));
    await tester.tap(find.text('فتح النموذج'));
    await tester.pumpAndSettle();
    final state = tester.state<FormState>(find.byType(Form));
    expect(state.validate(), false);
    await tester.pump();
    expect(find.text('أدخل مبلغ خصم أكبر من صفر'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '500');
    expect(state.validate(), true);
    expect(c.text, '500');
  });
  testWidgets('an existing non-preset percentage is preserved when editing',
      (tester) async {
    final c = TextEditingController(text: '5');
    addTearDown(c.dispose);
    await tester.pumpWidget(app(c));
    await tester.tap(find.text('فتح النموذج'));
    await tester.pumpAndSettle();
    expect(find.text('5٪'), findsOneWidget);
    expect(c.text, '5');
  });
}
