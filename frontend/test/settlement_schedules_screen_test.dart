import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/settlement_schedules_screen.dart';
import '../lib/services/person_onboarding_service.dart';

class FakeSchedules extends PersonOnboardingService {
  final List<Map<String, dynamic>> posts = [];
  bool fail = false;
  final proposal = <String, dynamic>{
    'proposalId': 'proposal1',
    'proposalDigest': 'digest1',
    'status': 'AWAITING_OWNER',
    'schedule': {'version': 1, 'frequency': 'WEEKLY'},
    'effectiveFrom': '2030-10-02T21:00:00.000Z',
    'effectiveTo': null
  };
  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    if (body != null) {
      posts.add(Map.of(body));
      if (fail) throw Exception('تعذر التحقق من النتيجة');
      proposal['status'] = 'AWAITING_APPROVAL';
    }
    return {
      'current': null,
      'proposals': [Map.of(proposal)]
    };
  }
}

void main() {
  testWidgets(
      'owner reviews dates in Baghdad and explicitly consents before POST',
      (tester) async {
    final api = FakeSchedules();
    await tester.pumpWidget(MaterialApp(
        home: SettlementSchedulesScreen(businessId: 'branch1', service: api)));
    await tester.pumpAndSettle();
    expect(find.textContaining('2030/10/03'), findsOneWidget);
    await tester.tap(find.text('مراجعة الجدول والموافقة'));
    await tester.pumpAndSettle();
    expect(api.posts, isEmpty);
    await tester.tap(find.text('أوافق على هذا الجدول'));
    await tester.pumpAndSettle();
    expect(api.posts.single, {
      'action': 'CONSENT',
      'branchId': 'branch1',
      'proposalId': 'proposal1',
      'proposalDigest': 'digest1'
    });
    expect(find.text('بانتظار اعتماد المنصة'), findsOneWidget);
  });
  testWidgets('dismissing review sends no consent', (tester) async {
    final api = FakeSchedules();
    await tester.pumpWidget(MaterialApp(
        home: SettlementSchedulesScreen(businessId: 'branch1', service: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مراجعة الجدول والموافقة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('رجوع'));
    await tester.pumpAndSettle();
    expect(api.posts, isEmpty);
  });
  testWidgets(
      'ambiguous result keeps exact proposal for retry without falsely showing approval',
      (tester) async {
    final api = FakeSchedules()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: SettlementSchedulesScreen(businessId: 'branch1', service: api)));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('مراجعة الجدول والموافقة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('أوافق على هذا الجدول'));
      await tester.pumpAndSettle();
    }
    expect(api.posts.length, 2);
    expect(api.posts[0], api.posts[1]);
    expect(find.text('بانتظار اعتماد المنصة'), findsNothing);
  });
}
