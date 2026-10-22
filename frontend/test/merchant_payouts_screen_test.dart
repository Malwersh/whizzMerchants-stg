import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/screens/merchant_payouts_screen.dart';
import 'package:whizz_merchants/services/person_onboarding_service.dart';

class PayoutApi extends PersonOnboardingService {
  final calls = <Map<String, dynamic>>[];
  bool requested = false, loseFirst = false, offCycle = false;
  String? payoutState;
  final amount = {
    'currency': 'IQD',
    'moneySchemaVersion': 1,
    'scale': 1000,
    'minorAmount': 7875000
  };
  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    if (body != null) {
      calls.add(Map.from(body));
      switch (body['action']) {
        case 'START_PAYOUT_DESTINATION':
          return {'proofId': 'proof', 'status': 'CODE_SENT'};
        case 'VERIFY_PAYOUT_DESTINATION':
          return {'proofId': 'proof', 'status': 'VERIFIED'};
        case 'REQUEST_PAYOUT':
          if (loseFirst) {
            loseFirst = false;
            throw Exception('انقطع الاتصال؛ أعد المحاولة نفسها');
          }
          requested = true;
          payoutState = 'UNDER_REVIEW';
          return {
            'payout': {'status': payoutState}
          };
        case 'ACK_PAYOUT_RECEIPT':
          payoutState = 'RECEIPT_CONFIRMED';
          return {
            'payout': {'status': payoutState}
          };
      }
      return {};
    }
    if (path.contains('view=merchant-account')) {
      return {
        'coverage': 'POSTED_MERCHANT_LEDGER_MOVEMENTS',
        'items': [],
        'amountLabels': {},
        'wallet': null,
        'nextCursor': null
      };
    }
    if (path.contains('view=payout-statement&')) {
      return {
        'batchId': 'MSB:test',
        'batchDigest': 'digest',
        'coverage': 'COMPLETE_SAVED_STATEMENT',
        'paymentStatus': 'UNPAID',
        'period': {
          if (offCycle) ...{
            'kind': 'MERCHANT_OFF_CYCLE_PERIOD',
            'fromUtc': '2026-10-20T21:00:00.000Z',
            'untilExclusiveUtc': '2026-10-21T17:00:00.000Z',
            'reason': 'صرف تعويض تجريبي قبل موعد التسوية'
          },
          'startLocalDate': '2026-10-01',
          'endExclusiveLocalDate': '2026-10-20'
        },
        'summary': {
          'accrualCount': 1,
          'amounts': {'merchantNet': amount}
        },
        'lines': [
          {
            'orderId': 'frozen-order-reference',
            'deliveredAt': '2026-10-19T20:40:00Z',
            'amounts': {'merchantNet': amount}
          }
        ],
      };
    }
    if (path.contains('view=payout-statements')) {
      return {
        'items': [
          {
            'batchId': 'MSB:test',
            'batchDigest': 'digest',
            'summary': {
              'amounts': {'merchantNet': amount},
              'accrualCount': 3
            },
            'period': {
              if (offCycle) ...{
                'kind': 'MERCHANT_OFF_CYCLE_PERIOD',
                'fromUtc': '2026-10-20T21:00:00.000Z',
                'untilExclusiveUtc': '2026-10-21T17:00:00.000Z',
                'reason': 'صرف تعويض تجريبي قبل موعد التسوية'
              },
              'startLocalDate': '2026-10-01',
              'endExclusiveLocalDate': '2026-10-20'
            },
            'approved': true,
            'payoutStatus': requested ? 'ACTIVE' : null
          }
        ]
      };
    }
    return {
      'items': payoutState == null
          ? []
          : [
              {
                'payoutId': 'MPO:test',
                'version': 4,
                'amount': amount,
                'method': 'CASH',
                'status': payoutState,
                'destination': 'مالك المطعم'
              }
            ]
    };
  }
}

class ManyStatementsApi extends PayoutApi {
  final reads = <String>[];
  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    reads.add(path);
    final result =
        await super.call(path, body: body, authenticated: authenticated);
    if (body == null && path.contains('view=payout-statements')) {
      final row = Map<String, dynamic>.from((result['items'] as List).first);
      final more = Uri.parse(path).queryParameters['cursor'] != null;
      return {
        'items': List.generate(more ? 1 : 20,
            (i) => {...row, 'batchId': 'MSB:page-${more ? 2 : 1}-$i'}),
        'nextCursor': more ? null : 'second-page'
      };
    }
    return result;
  }
}

Future<void> open(WidgetTester tester, PayoutApi api) async {
  await tester.pumpWidget(MaterialApp(
      home: MerchantPayoutsScreen(
          businessId: 'branch', service: api, autoRefreshAccount: false)));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester t, Finder target) async {
  if (target.evaluate().isEmpty) {
    await t.tap(find.text('الكشوف'));
    await t.pumpAndSettle();
    if (target.evaluate().isEmpty) {
      await t.tap(find.text('طلبات الصرف'));
      await t.pumpAndSettle();
    }
  }
  await t.scrollUntilVisible(target, 250,
      scrollable: find.byType(Scrollable).first);
  await t.pumpAndSettle();
  await t.ensureVisible(target);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
      'separate sections keep long statements lazy and load the next server page without requesting money',
      (t) async {
    final api = ManyStatementsApi();
    await open(t, api);
    expect(find.text('حساب المطعم ومستحقاته'), findsOneWidget);
    expect(find.text('طلب صرف المستحقات'), findsNothing);
    await t.tap(find.text('الكشوف'));
    await t.pumpAndSettle();
    expect(find.text('حساب المطعم ومستحقاته'), findsNothing);
    expect(find.text('طلب صرف المستحقات').evaluate().length, lessThan(10));
    expect(find.textContaining('MSB:page-'), findsNothing);
    await t.scrollUntilVisible(find.text('تحميل كشوف إضافية'), 500,
        maxScrolls: 60);
    await t.tap(find.text('تحميل كشوف إضافية'));
    await t.pumpAndSettle();
    expect(api.reads.any((p) => p.contains('cursor=second-page')), isTrue);
    expect(api.calls, isEmpty);
    await t.tap(find.text('طلبات الصرف'));
    await t.pumpAndSettle();
    expect(find.text('لا توجد طلبات صرف حتى الآن.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'off-cycle statement shows exact Baghdad cutoff and reason without implying payout',
      (t) async {
    final api = PayoutApi()..offCycle = true;
    await open(t, api);
    await reveal(t, find.text('تفاصيل الكشف والطلبات'));
    await t.tap(find.text('الفترة وسبب التسوية'));
    await t.pumpAndSettle();
    expect(find.textContaining('كشف استثنائي خارج الدورة'), findsWidgets);
    await t.ensureVisible(find.text('تفاصيل الكشف والطلبات'));
    await t.tap(find.text('تفاصيل الكشف والطلبات'));
    await t.pumpAndSettle();
    expect(find.textContaining('2026-10-21 20:00'), findsWidgets);
    expect(
        find.textContaining('صرف تعويض تجريبي قبل موعد التسوية'), findsWidgets);
    expect(api.calls, isEmpty);
    await t.tap(find.text('إغلاق'));
    await t.pumpAndSettle();
  });

  testWidgets(
      'owner opens immutable statement lines and Baghdad delivery without a payout mutation',
      (t) async {
    final api = PayoutApi();
    await open(t, api);
    final button = find.text('تفاصيل الكشف والطلبات');
    await reveal(t, button);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(find.text('تفاصيل كشف المستحقات'), findsOneWidget);
    expect(find.text('الطلب: frozen-order-reference'), findsOneWidget);
    expect(find.text('التسليم بتوقيت العراق: 2026-10-19 23:40'), findsOneWidget);
    expect(find.text('لم يُصرف — اعتماد الكشف وحده لا يعني الدفع'),
        findsOneWidget);
    expect(api.calls, isEmpty);
    await t.tap(find.text('إغلاق'));
    await t.pumpAndSettle();
  });

  testWidgets(
      'owner requests cash against exact saved batch; bank stays disabled and no client amount or actor is sent',
      (t) async {
    final api = PayoutApi();
    await open(t, api);
    await reveal(t, find.text('طلب صرف المستحقات'));
    await t.tap(find.text('طلب صرف المستحقات'));
    await t.pumpAndSettle();
    await t.tap(find.text('إرسال طلب الصرف'));
    await t.pumpAndSettle();
    final sent = api.calls.single;
    expect(sent['action'], 'REQUEST_PAYOUT');
    expect(sent['branchId'], 'branch');
    expect(sent['batchId'], 'MSB:test');
    expect(sent['amount'], isNull);
    expect(sent['actorId'], isNull);
    expect(sent['method'], 'CASH');
    expect(sent['requestId'], isNotEmpty);
    await reveal(t, find.text('بانتظار مراجعة الإدارة'));
    await t.pumpAndSettle();
    expect(find.text('بانتظار مراجعة الإدارة'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'uncertain request preserves its identity on retry and creates only one active request',
      (t) async {
    final api = PayoutApi()..loseFirst = true;
    await open(t, api);
    await reveal(t, find.text('طلب صرف المستحقات'));
    await t.tap(find.text('طلب صرف المستحقات'));
    await t.pumpAndSettle();
    await t.tap(find.text('إرسال طلب الصرف'));
    await t.pumpAndSettle();
    expect(find.textContaining('انقطع الاتصال'), findsOneWidget);
    await t.tap(find.text('إرسال طلب الصرف'));
    await t.pumpAndSettle();
    expect(api.calls.length, 2);
    expect(api.calls[0]['requestId'], api.calls[1]['requestId']);
    await reveal(t, find.text('بانتظار مراجعة الإدارة'));
    await t.pumpAndSettle();
    expect(find.text('بانتظار مراجعة الإدارة'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'Zain destination needs code verification before request and the proof is bound without changing login phone',
      (t) async {
    final api = PayoutApi();
    await open(t, api);
    await reveal(t, find.text('طلب صرف المستحقات'));
    await t.tap(find.text('طلب صرف المستحقات'));
    await t.pumpAndSettle();
    await t.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(DropdownButton<String>)));
    await t.pumpAndSettle();
    await t.tap(find.text('حوالة زين كاش').last);
    await t.pumpAndSettle();
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'إرسال طلب الصرف'))
            .onPressed,
        isNull);
    await t.enterText(find.byType(TextField).first, '07800868280');
    await t.tap(find.text('إرسال رمز تحقق للوجهة'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, '123456');
    await t.tap(find.text('تأكيد الرقم'));
    await t.pumpAndSettle();
    await t.tap(find.text('إرسال طلب الصرف'));
    await t.pumpAndSettle();
    expect(api.calls.map((v) => v['action']), [
      'START_PAYOUT_DESTINATION',
      'VERIFY_PAYOUT_DESTINATION',
      'REQUEST_PAYOUT'
    ]);
    expect(api.calls.last['destinationProofId'], 'proof');
    expect(api.calls.last['phone'], isNull);
    expect(api.calls.last['method'], 'ZAIN_CASH');
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'receipt requires explicit confirmation of exact net amount and cannot be performed by opening the page',
      (t) async {
    final api = PayoutApi()
      ..requested = true
      ..payoutState = 'AWAITING_RECEIPT';
    await open(t, api);
    expect(api.calls, isEmpty);
    await reveal(t, find.text('تأكيد استلام كامل المبلغ'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('تأكيد استلام كامل المبلغ'));
    await t.pumpAndSettle();
    await t.tap(find.text('تأكيد استلام كامل المبلغ'));
    await t.pumpAndSettle();
    expect(api.calls, isEmpty);
    await t.tap(find.text('نعم، استلمت كامل المبلغ'));
    await t.pumpAndSettle();
    expect(api.calls.single['action'], 'ACK_PAYOUT_RECEIPT');
    expect(api.calls.single['receivedAmount'], 7875);
    expect(api.calls.single['accepted'], true);
    await reveal(t, find.text('أكدت الاستلام — بانتظار المطابقة'));
    await t.pumpAndSettle();
    expect(find.text('أكدت الاستلام — بانتظار المطابقة'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
