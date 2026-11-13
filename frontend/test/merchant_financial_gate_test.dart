import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/providers/auth_provider_riverpod.dart';
import 'package:whizz_merchants/services/merchant_financial_session_state.dart';
import 'package:whizz_merchants/widgets/merchant_financial_gate.dart';
class OwnerAuth extends AuthNotifier {
  OwnerAuth() : super(signOutAction: () async {}) {
    state = const AuthState(status: AuthStatus.authenticated, currentUser: {'sub': 'owner1'});
  }
  void changeOwner() {state = const AuthState(status: AuthStatus.authenticated, currentUser: {'sub': 'owner2'});}
}
void main() {
  final session = MerchantFinancialSessionState.instance;
  setUp(session.clear);
  tearDown(session.clear);
  testWidgets('financial data is absent until verified and is destroyed on background', (tester) async {
    final auth = OwnerAuth();
    await tester.pumpWidget(ProviderScope(overrides: [authProviderRiverpod.overrideWith((ref) => auth)], child: const MaterialApp(home: MerchantFinancialGate(branchId: 'branch1', child: Text('PRIVATE_AMOUNT')))));
    expect(find.text('PRIVATE_AMOUNT'), findsNothing);
    session.grant(owner: 'owner1', branch: 'branch1', device: 'd', token: 't', expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300);
    await tester.pump(); expect(find.text('PRIVATE_AMOUNT'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(session.access('branch1'), isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(); expect(find.text('PRIVATE_AMOUNT'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('changing owner cannot reuse the previous financial session', (tester) async {
    final auth = OwnerAuth();
    await tester.pumpWidget(ProviderScope(overrides: [authProviderRiverpod.overrideWith((ref) => auth)], child: const MaterialApp(home: MerchantFinancialGate(branchId: 'branch1', child: Text('PRIVATE_AMOUNT')))));
    session.grant(owner: 'owner1', branch: 'branch1', device: 'd', token: 't', expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300);
    await tester.pump(); auth.changeOwner(); await tester.pump();
    expect(find.text('PRIVATE_AMOUNT'), findsNothing);
    expect(session.access('branch1'), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test('expired sessions or another branch never supply a transport token', () {
    session.grant(owner: 'owner1', branch: 'branch1', device: 'd', token: 't', expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 1);
    expect(session.access('branch1'), isNull);
    session.grant(owner: 'owner1', branch: 'branch1', device: 'd', token: 't', expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300);
    expect(session.access('branch2'), isNull);
    expect(session.unlocked('owner2', 'branch1'), isFalse);
  });
  testWidgets('background locks the financial session even with no financial gate mounted', (tester) async {
    await tester.pumpWidget(const MaterialApp(home:Text('OPERATIONS')));
    session.grant(owner:'owner1',branch:'branch1',device:'d',token:'t',expiresAt:DateTime.now().millisecondsSinceEpoch ~/ 1000+300);
    expect(session.access('branch1'),isNotNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(session.access('branch1'),isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  });
}
