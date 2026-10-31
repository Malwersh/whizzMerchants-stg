import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/widgets/merchant_financial_account.dart';
import 'package:whizz_merchants/services/person_onboarding_service.dart';

class AccountApi extends PersonOnboardingService {
  final bool zeroNet;
  AccountApi({this.zeroNet = false});
  final queries = <Map<String, String>>[];
  bool revoked = false;
  Map<String, dynamic> m(int value) => {
        'currency': 'IQD',
        'scale': 1000,
        'moneySchemaVersion': 1,
        'minorAmount': value * 1000
      };
  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    expect(body, isNull);
    final q = Uri.parse(path).queryParameters;
    queries.add(q);
    if (revoked) throw Exception('صلاحية القراءة مسحوبة');
    final more = q['cursor'] != null;
    return {
      'coverage': 'POSTED_MERCHANT_LEDGER_MOVEMENTS',
      'wallet': {'pendingIqd': 43575, 'version': 8},
      'amountLabels': {
        'merchantNet': 'صافي مستحق المطعم',
        'merchantFundedDiscount': 'خصم يموله المطعم',
        'goodsGross': 'قيمة المنتجات قبل الخصم'
      },
      'nextCursor': more ? null : 'next',
      'items': [
        if (!more)
          {
            'entryId': 'one',
            'operationId': 'FCS:one',
            'kind': 'ORDER_ACCRUAL',
            'state': zeroNet ? 'NO_PAYOUT_REQUIRED' : 'PENDING_SETTLEMENT',
            'evidenceVerified': true,
            'occurredAt': '2026-10-20T03:30:00.000Z',
            'orderNumber': 'ORD-212',
            'amounts': {
              'goodsGross': m(7000),
              'merchantFundedDiscount': m(700),
              'merchantNet': m(zeroNet ? 0 : 5250)
            }
          },
        if (more)
          {
            'entryId': 'paid',
            'operationId': 'MPO:one',
            'kind': 'PAYOUT',
            'state': 'PAID',
            'evidenceVerified': true,
            'occurredAt': '2026-10-20T03:30:00.000Z',
            'amount': m(2000),
            'method': 'CASH',
            'externalReference': 'CASH-REF',
            'executionFeeIqd': 0
          },
      ]
    };
  }
}

class ManyAccountApi extends AccountApi {
  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    final result =
        await super.call(path, body: body, authenticated: authenticated);
    final row = Map<String, dynamic>.from((result['items'] as List).first);
    return {
      ...result,
      'nextCursor': null,
      'items': List.generate(
          100, (i) => {...row, 'entryId': 'entry-$i', 'orderNumber': 'ORD-$i'})
    };
  }
}

void main() {
  testWidgets(
      'one hundred loaded movements display twenty at a time and preserve all totals',
      (t) async {
    final api = ManyAccountApi();
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MerchantFinancialAccount(
                    businessId: 'branch', service: api, autoRefresh: false)))));
    await t.pumpAndSettle();
    expect(find.text('طلب ORD-19'), findsOneWidget);
    expect(find.text('طلب ORD-20'), findsNothing);
    expect(find.text('525000 د.ع'), findsWidgets);
    await t.ensureVisible(find.text('عرض ٢٠ حركة إضافية'));
    await t.tap(find.text('عرض ٢٠ حركة إضافية'));
    await t.pumpAndSettle();
    expect(find.text('طلب ORD-39'), findsOneWidget);
    expect(find.text('طلب ORD-40'), findsNothing);
    expect(api.queries, hasLength(1));
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'zero-net completed order remains visible without a pending payout label',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MerchantFinancialAccount(
                    businessId: 'branch',
                    service: AccountApi(zeroNet: true),
                    autoRefresh: false)))));
    await t.pumpAndSettle();
    final order = find.text('طلب ORD-212');
    await t.ensureVisible(order);
    expect(find.textContaining('صافي المستحق صفر — لا يتطلب صرفًا'),
        findsOneWidget);
    await t.tap(order);
    await t.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(ExpansionTile), matching: find.text('0 د.ع')),
        findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'merchant sees global pending balance separately from paginated period accruals and actual disbursements, then filters date and clears revoked data',
      (t) async {
    final api = AccountApi();
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MerchantFinancialAccount(
                    businessId: 'branch', service: api, autoRefresh: false)))));
    await t.pumpAndSettle();
    expect(find.text('إجمالي المستحقات غير المصروفة · كل الفترات'),
        findsOneWidget);
    expect(find.textContaining('43575'), findsOneWidget);
    expect(find.textContaining('المجاميع للقيود المحمّلة فقط'), findsOneWidget);
    final more = find.text('تحميل بقية الحركات');
    await t.scrollUntilVisible(more, 350,
        scrollable: find.byType(Scrollable).first);
    await t.tap(more);
    await t.pumpAndSettle();
    expect(api.queries.last['cursor'], 'next');
    expect(find.text('اكتمل تحميل القيود المسجلة للفترة.'), findsOneWidget);
    final paid = find.text('صرف مستحقات');
    await t.ensureVisible(paid);
    await t.tap(paid);
    await t.pumpAndSettle();
    expect(find.text('مرجع التنفيذ: CASH-REF'), findsOneWidget);
    final today = find.text('اليوم');
    await t.ensureVisible(today);
    await t.tap(today);
    await t.pumpAndSettle();
    expect(api.queries.last['fromLocalDate'],
        api.queries.last['throughLocalDate']);
    expect(api.queries.last['cursor'], isNull);
    api.revoked = true;
    await t.ensureVisible(find.byTooltip('تحديث الحساب'));
    await t.tap(find.byTooltip('تحديث الحساب'));
    await t.pumpAndSettle();
    expect(find.textContaining('صلاحية القراءة مسحوبة'), findsOneWidget);
    expect(find.textContaining('43575'), findsNothing);
    expect(find.text('طلب ORD-212'), findsNothing);
  });
}
