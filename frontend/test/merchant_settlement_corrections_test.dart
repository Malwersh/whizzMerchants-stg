import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/services/person_onboarding_service.dart';
import 'package:whizz_merchants/widgets/merchant_settlement_corrections.dart';

class Api extends PersonOnboardingService {
  final calls = <String>[];
  final pending = <String, Completer<Map<String, dynamic>>>{};
  bool fail = false;
  int credit = 0;
  final requests = <Map<String, dynamic>>[];
  bool failRequest = false;
  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    calls.add(path);
    if (body != null) {
      requests.add(Map.from(body));
      if (failRequest) throw Exception('تعذر الاتصال');
      return {
        'payout': {'status': 'UNDER_REVIEW'}
      };
    }
    if (fail) throw Exception('unavailable');
    final branch = Uri.parse(path).queryParameters['branchId']!;
    if (pending.containsKey(branch)) return pending[branch]!.future;
    return {
      'items': <dynamic>[],
      'position': {'creditIqd': credit, 'debtIqd': 6000},
      'nextCursor': null
    };
  }
}

Widget app(Api api, String branch) => MaterialApp(
    home: Scaffold(
        body: MerchantSettlementCorrections(
            key: const ValueKey('corrections'),
            businessId: branch,
            service: api)));
Future<void> expand(WidgetTester t) async {
  await t.tap(find.text('تصحيحات التسويات'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
      'owner view loads explicit branch and distinguishes debt from paid money',
      (t) async {
    final api = Api();
    await t.pumpWidget(app(api, 'branch'));
    await expand(t);
    expect(api.calls, isEmpty);
    await t.tap(find.text('عرض / تحديث التصحيحات'));
    await t.pumpAndSettle();
    expect(find.text('مديونية لم تُحصّل'), findsOneWidget);
    expect(find.text('6000 د.ع'), findsOneWidget);
    expect(Uri.parse(api.calls.single).queryParameters['branchId'], 'branch');
  });
  testWidgets(
      'owner cash correction request is explicit and retries preserve request id',
      (t) async {
    final api = Api()
      ..credit = 3000
      ..failRequest = true;
    await t.pumpWidget(app(api, 'branch'));
    await expand(t);
    await t.tap(find.text('عرض / تحديث التصحيحات'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('طلب صرف المستحق الإضافي'));
    await t.tap(find.text('طلب صرف المستحق الإضافي'));
    await t.pumpAndSettle();
    expect(api.requests, isEmpty);
    await t.tap(find.text('إرسال طلب الصرف'));
    await t.pumpAndSettle();
    expect(api.requests.length, 1);
    api.failRequest = false;
    await t.ensureVisible(find.text('طلب صرف المستحق الإضافي'));
    await t.tap(find.text('طلب صرف المستحق الإضافي'));
    await t.pumpAndSettle();
    await t.tap(find.text('إرسال طلب الصرف'));
    await t.pumpAndSettle();
    expect(api.requests.length, 2);
    expect(api.requests[0]['requestId'], api.requests[1]['requestId']);
    expect(api.requests[1]['action'], 'REQUEST_CORRECTION_PAYOUT');
    expect(api.requests[1].containsKey('amount'), false);
    expect(find.text('طلب صرف المستحق الإضافي'), findsNothing);
  });
  testWidgets('failed refresh hides formerly loaded amounts', (t) async {
    final api = Api();
    await t.pumpWidget(app(api, 'branch'));
    await expand(t);
    await t.tap(find.text('عرض / تحديث التصحيحات'));
    await t.pumpAndSettle();
    api.fail = true;
    await t.tap(find.text('عرض / تحديث التصحيحات'));
    await t.pumpAndSettle();
    expect(find.text('6000 د.ع'), findsNothing);
    expect(
        find.text('تعذر التحقق من التصحيحات. أعد المحاولة.'), findsOneWidget);
  });
  testWidgets(
      'late response for previous branch cannot replace current branch position',
      (t) async {
    final api = Api();
    api.pending['a'] = Completer();
    await t.pumpWidget(app(api, 'a'));
    await expand(t);
    await t.tap(find.text('عرض / تحديث التصحيحات'));
    await t.pump();
    await t.pumpWidget(app(api, 'b'));
    await t.pump();
    await t.tap(find.text('عرض / تحديث التصحيحات'));
    await t.pumpAndSettle();
    api.pending['a']!.complete({
      'items': <dynamic>[],
      'position': {'creditIqd': 9999, 'debtIqd': 0},
      'nextCursor': null
    });
    await t.pumpAndSettle();
    expect(find.text('9999 د.ع'), findsNothing);
    expect(find.text('6000 د.ع'), findsOneWidget);
  });
}
