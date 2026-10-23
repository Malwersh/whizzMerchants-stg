import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/services/branch_device_service.dart';
import 'package:whizz_merchants/services/branch_employee_access.dart';
import 'package:whizz_merchants/widgets/branch_employee_status_control.dart';

class StatusApi extends BranchDeviceService {
  final calls = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? pending;
  bool fail = false;
  @override
  Future<Map<String, dynamic>> call(String token, Map<String, dynamic> body,
      {String? session}) async {
    calls.add({'token': token, 'session': session, ...body});
    if (pending != null) return pending!.future;
    if (fail) throw BranchDeviceException('PERMISSION_REQUIRED');
    return {
      'businessId': 'branch',
      'acceptingOrders': body['acceptingOrders'] ?? false,
      'revision': 'revision'
    };
  }
}

BranchEmployeeAccess access(StatusApi api, {bool allowed = true}) =>
    BranchEmployeeAccess(
        api: api,
        token: 'device',
        session: 'employee',
        businessId: 'branch',
        profile: {
          'capabilities': {'editStatus': allowed}
        },
        lock: () async {});
Widget app(BranchEmployeeAccess value) => MaterialApp(
    home: Scaffold(
        appBar: AppBar(actions: [BranchEmployeeStatusControl(access: value)])));
void main() {
  testWidgets(
      'status transport uses only device and staff session with a read revision',
      (tester) async {
    final api = StatusApi();
    await tester.pumpWidget(app(access(api)));
    await tester.pumpAndSettle();
    expect(api.calls.single['action'], 'read_status');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(api.calls.last, {
      'token': 'device',
      'session': 'employee',
      'action': 'set_status',
      'acceptingOrders': true,
      'baseRevision': 'revision'
    });
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });
  testWidgets('absent status permission makes no request and shows no control',
      (tester) async {
    final api = StatusApi();
    await tester.pumpWidget(app(access(api, allowed: false)));
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
    expect(find.byType(Switch), findsNothing);
  });
  testWidgets('failure removes uncertain status and requires a fresh read',
      (tester) async {
    final api = StatusApi();
    await tester.pumpWidget(app(access(api)));
    await tester.pumpAndSettle();
    api.fail = true;
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    expect(find.byTooltip('تحديث حالة الاستقبال'), findsOneWidget);
    api.fail = false;
    await tester.tap(find.byTooltip('تحديث حالة الاستقبال'));
    await tester.pumpAndSettle();
    expect(api.calls.last['action'], 'read_status');
  });
  testWidgets('status stays pending until server acknowledgment',
      (tester) async {
    final api = StatusApi();
    await tester.pumpWidget(app(access(api)));
    await tester.pumpAndSettle();
    api.pending = Completer();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    api.pending!.complete(
        {'businessId': 'branch', 'acceptingOrders': true, 'revision': 'new'});
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });
  testWidgets('revocation ignores a late read and removes the control',
      (tester) async {
    final api = StatusApi()..pending = Completer();
    await tester.pumpWidget(app(access(api)));
    await tester.pumpWidget(app(access(api, allowed: false)));
    api.pending!.complete(
        {'businessId': 'branch', 'acceptingOrders': true, 'revision': 'old'});
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    expect(api.calls.length, 1);
  });
}
