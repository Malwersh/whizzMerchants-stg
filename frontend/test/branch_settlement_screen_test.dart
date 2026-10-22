import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/screens/merchant_payouts_screen.dart';
import 'package:whizz_merchants/services/branch_device_service.dart';
import 'package:whizz_merchants/services/branch_employee_access.dart';
import 'package:whizz_merchants/services/branch_settlement_service.dart';
import 'merchant_payouts_screen_test.dart' show PayoutApi;

class DeviceSettlements extends BranchDeviceService {
  final data = PayoutApi();
  final calls = <Map<String, dynamic>>[];
  bool requestAllowed = true, receiveAllowed = true;
  @override
  Future<Map<String, dynamic>> call(String token, Map<String, dynamic> body,
      {String? session}) async {
    expect(token, 'employee-device');
    expect(session, 'employee-pin-session');
    expect(body['action'], 'settlements');
    calls.add(Map.of(body));
    final input = Map<String, dynamic>.from(body['input']);
    if (input['view'] == 'payout-context')
      return {
        'actor': {
          'name': 'محمد الموظف',
          'roleLabel': 'موظف مالي',
          'businessName': 'مطعم الاختبار'
        },
        'can': {'request': requestAllowed, 'receive': receiveAllowed},
        'methods': ['CASH'],
        'destination': null
      };
    return data.call(
        body['httpMethod'] == 'GET'
            ? 'settlement-schedules?${Uri(queryParameters: input.map((k, v) => MapEntry(k, v.toString()))).query}'
            : 'settlement-schedules',
        body: body['httpMethod'] == 'GET' ? null : input);
  }
}

BranchSettlementService service(DeviceSettlements api) =>
    BranchSettlementService(BranchEmployeeAccess(
        api: api,
        token: 'employee-device',
        session: 'employee-pin-session',
        businessId: 'branch1',
        profile: {
          'staff': {'role': 'FINANCIAL_EMPLOYEE', 'permissionSchema': 2},
          'capabilities': {'readSettlements': true}
        },
        lock: () async {}));
Future<void> show(WidgetTester tester, DeviceSettlements api) async {
  tester.view.physicalSize = const Size(1100, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      home: MerchantPayoutsScreen(
          businessId: 'branch1',
          service: service(api),
          autoRefreshAccount: false)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'employee settlement screen uses device transport and confirms only under receive grant',
      (tester) async {
    final api = DeviceSettlements();
    api.data.requested = true;
    api.data.payoutState = 'AWAITING_RECEIPT';
    await show(tester, api);
    expect(find.textContaining('محمد الموظف — موظف مالي'), findsOneWidget);
    await tester.tap(find.text('طلبات الصرف'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد استلام كامل المبلغ'));
    await tester.pumpAndSettle();
    expect(api.data.calls, isEmpty);
    await tester.tap(find.text('نعم، استلمت كامل المبلغ'));
    await tester.pumpAndSettle();
    expect(api.data.calls.single['action'], 'ACK_PAYOUT_RECEIPT');
    expect(api.data.calls.single.containsKey('actorId'), false);
    expect(api.data.calls.single.containsKey('role'), false);
    expect(
        api.calls.every((c) => !(c['input'] as Map).containsKey('accessToken')),
        true);
  });
  testWidgets(
      'read-only employee sees statement details without request or receipt controls',
      (tester) async {
    final api = DeviceSettlements()
      ..requestAllowed = false
      ..receiveAllowed = false;
    api.data.requested = true;
    api.data.payoutState = 'AWAITING_RECEIPT';
    await show(tester, api);
    await tester.tap(find.text('الكشوف'));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل الكشف والطلبات'), findsOneWidget);
    expect(find.text('طلب صرف المستحقات'), findsNothing);
    await tester.tap(find.text('طلبات الصرف'));
    await tester.pumpAndSettle();
    expect(find.text('تأكيد استلام كامل المبلغ'), findsNothing);
    expect(find.text('لم أستلم / طلب مراجعة'), findsNothing);
    expect(api.data.calls, isEmpty);
  });
  testWidgets('employee requests cash without owner OTP or a client role',
      (tester) async {
    final api = DeviceSettlements();
    await show(tester, api);
    await tester.tap(find.text('الكشوف'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طلب صرف المستحقات'));
    await tester.pumpAndSettle();
    expect(find.textContaining('هويتك وصفتك'), findsOneWidget);
    expect(find.text('رقم محفظة زين كاش لهذا الطلب'), findsNothing);
    await tester.tap(find.text('إرسال طلب الصرف'));
    await tester.pumpAndSettle();
    expect(api.data.calls.single['action'], 'REQUEST_PAYOUT');
    expect(api.data.calls.single['method'], 'CASH');
    expect(api.data.calls.single.containsKey('ownerId'), false);
  });
  test('employee transport refuses a different branch before any request',
      () async {
    final api = DeviceSettlements();
    await expectLater(
        service(api).call('settlement-schedules?view=payouts&branchId=foreign'),
        throwsStateError);
    expect(api.calls, isEmpty);
  });
}
