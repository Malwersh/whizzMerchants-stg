import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/screens/branch_employee_wallet_screen.dart';
import 'package:whizz_merchants/services/branch_device_service.dart';
import 'package:whizz_merchants/services/branch_employee_access.dart';
import 'package:whizz_merchants/services/branch_employee_wallet_service.dart';

BranchEmployeeAccess access(
        {String session = 'staff', bool balance = true, bool history = true}) =>
    BranchEmployeeAccess(
        api: BranchDeviceService(),
        token: 'device-only',
        session: session,
        businessId: 'branch-a',
        profile: {
          'capabilities': {
            'readWalletBalance': balance,
            'readWalletTransactions': history
          }
        },
        lock: () async {});
Widget screen(BranchEmployeeAccess access, BranchEmployeeWalletService api) =>
    MaterialApp(
        home: Scaffold(
            body: BranchEmployeeWalletScreen(access: access, service: api)));

class WalletApi extends BranchEmployeeWalletService {
  final calls = <String>[];
  Completer<Map<String, dynamic>>? pending;
  bool fail = false;
  @override
  Future<Map<String, dynamic>> read(BranchEmployeeAccess access, String kind,
      {String? cursor,
      String? from,
      String? to,
      bool exportCsv = false}) async {
    calls.add('${access.session}:$kind:${cursor ?? ''}');
    if (fail) throw BranchDeviceException('MEMBERSHIP_REVOKED');
    if (pending != null && access.session == 'old') return pending!.future;
    if (kind == 'balance')
      return {
        'availableBalance': 10000,
        'lockedBalance': 2000,
        'status': 'ACTIVE',
        'asOf': '2026-10-15T12:00:00Z'
      };
    return {
      'transactions': [
        {
          'amount': 500,
          'description': 'حركة مالية',
          'createdAt': '2026-10-15T12:00:00Z'
        }
      ],
      'nextCursor': cursor == null ? 'page-2' : null
    };
  }
}

void main() {
  test(
      'wallet client uses only device/session and refuses unsupported actions locally',
      () async {
    final requests = <http.Request>[];
    final api = BranchEmployeeWalletService(client: MockClient((r) async {
      requests.add(r);
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {'availableBalance': 42}
          }),
          200);
    }));
    expect((await api.read(access(), 'balance'))['availableBalance'], 42);
    expect(requests.single.headers['Authorization'], 'Bearer device-only');
    expect(requests.single.headers['X-Staff-Session'], 'staff');
    expect(requests.single.url.queryParameters, {'businessId': 'branch-a'});
    await expectLater(
        api.read(access(balance: false, history: false), 'balance'),
        throwsA(isA<BranchDeviceException>()));
    await expectLater(
        api.read(access(), 'request'), throwsA(isA<BranchDeviceException>()));
    expect(requests.length, 1);
  });
  testWidgets(
      'wallet displays balances and ledger pages without transfer controls',
      (t) async {
    final api = WalletApi();
    await t.pumpWidget(screen(access(), api));
    await t.pumpAndSettle();
    expect(find.text('الرصيد المتاح: 10000 د.ع'), findsOneWidget);
    expect(find.text('الرصيد المحجوز: 2000 د.ع'), findsOneWidget);
    expect(find.textContaining('حركة مالية'), findsOneWidget);
    expect(find.text('تحويل'), findsNothing);
    await t.tap(find.text('المزيد من الحركات'));
    await t.pumpAndSettle();
    expect(api.calls.last, 'staff:transactions:page-2');
    expect(find.text('المزيد من الحركات'), findsNothing);
  });
  testWidgets(
      'revoking balance access clears displayed balances and keeps authorized ledger only',
      (t) async {
    final api = WalletApi();
    await t.pumpWidget(screen(access(), api));
    await t.pumpAndSettle();
    await t.pumpWidget(screen(access(balance: false), api));
    await t.pumpAndSettle();
    expect(find.textContaining('الرصيد المتاح:'), findsNothing);
    expect(find.textContaining('حركة مالية'), findsOneWidget);
  });
  testWidgets(
      'late response from an old employee session cannot populate a new session',
      (t) async {
    final api = WalletApi()..pending = Completer<Map<String, dynamic>>();
    await t.pumpWidget(screen(access(session: 'old', history: false), api));
    await t.pump();
    await t.pumpWidget(screen(access(session: 'new', history: false), api));
    await t.pump();
    api.pending!.complete({'availableBalance': 999999, 'lockedBalance': 1});
    await t.pumpAndSettle();
    expect(find.textContaining('999999'), findsNothing);
  });
  testWidgets('history-only employee never triggers balance loading',
      (t) async {
    final api = WalletApi();
    await t.pumpWidget(screen(access(balance: false), api));
    await t.pumpAndSettle();
    expect(api.calls, ['staff:transactions:']);
    expect(find.textContaining('الرصيد المتاح:'), findsNothing);
  });
  testWidgets(
      'failed authorization refresh removes previously visible financial data',
      (t) async {
    final api = WalletApi();
    await t.pumpWidget(screen(access(), api));
    await t.pumpAndSettle();
    api.fail = true;
    await t.tap(find.text('تحديث المحفظة'));
    await t.pumpAndSettle();
    expect(find.textContaining('الرصيد المتاح:'), findsNothing);
    expect(find.textContaining('حركة مالية'), findsNothing);
    expect(find.textContaining('تغيرت عضويتك'), findsOneWidget);
  });
}
