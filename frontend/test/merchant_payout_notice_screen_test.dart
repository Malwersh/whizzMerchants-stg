import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/providers/auth_provider_riverpod.dart';
import 'package:whizz_merchants/services/person_onboarding_service.dart';
import 'package:whizz_merchants/services/merchant_financial_session_state.dart';
import 'package:whizz_merchants/screens/merchant_payout_notice_screen.dart';

class Owner extends AuthNotifier {
  Owner() : super(signOutAction: () async {}) {
    state = const AuthState(
        status: AuthStatus.authenticated, currentUser: {'sub': 'owner'});
  }
}

class Api extends PersonOnboardingService {
  final calls = <String>[];
  Map<String, dynamic> result = {
    'payoutId': 'MPO:one',
    'branchId': 'branch',
    'status': 'PAID',
    'amount': {
      'currency': 'IQD',
      'scale': 1000,
      'moneySchemaVersion': 1,
      'minorAmount': 6250000
    }
  };
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    expect(body, isNull);
    calls.add(path);
    if (pending != null) return await pending!.future;
    return result;
  }
}

void main() {
  final session = MerchantFinancialSessionState.instance;
  setUp(session.clear);
  tearDown(session.clear);
  Future<void> open(WidgetTester t, Api api) async {
    await t.pumpWidget(ProviderScope(
        overrides: [authProviderRiverpod.overrideWith((_) => Owner())],
        child: MaterialApp(
            home: MerchantPayoutNoticeScreen(
                businessId: 'branch', payoutId: 'MPO:one', service: api))));
    await t.pump();
    expect(api.calls, isEmpty);
    session.grant(
        owner: 'owner',
        branch: 'branch',
        device: 'device',
        token: 'token',
        expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300);
    await t.pumpAndSettle();
  }

  testWidgets(
      'notification target is read only after owner unlock; amount and status come from server',
      (t) async {
    final api = Api();
    await open(t, api);
    expect(find.text('6,250 د.ع'), findsOneWidget);
    expect(find.text('تمت المطابقة والصرف'), findsOneWidget);
    expect(find.textContaining('MPO:'), findsNothing);
    expect(api.calls.single, contains('payoutId=MPO%3Aone'));
    await t.pumpWidget(const SizedBox());
    session.clear();
  });
  testWidgets('another branch or operation response cannot expose money',
      (t) async {
    final api = Api()
      ..result = {
        'payoutId': 'MPO:other',
        'branchId': 'foreign',
        'status': 'PAID',
        'amount': {
          'currency': 'IQD',
          'scale': 1000,
          'moneySchemaVersion': 1,
          'minorAmount': 6250000
        }
      };
    await open(t, api);
    expect(find.text('هذه العملية غير متاحة لهذا الفرع.'), findsOneWidget);
    expect(find.text('6,250 د.ع'), findsNothing);
    await t.pumpWidget(const SizedBox());
    session.clear();
  });
  testWidgets('background destroys private notification detail', (t) async {
    final api = Api();
    await open(t, api);
    expect(find.text('6,250 د.ع'), findsOneWidget);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(find.text('6,250 د.ع'), findsNothing);
    await t.pumpWidget(const SizedBox());
    session.clear();
  });
}
