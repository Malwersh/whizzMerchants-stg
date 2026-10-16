import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:whizz_merchants/services/statement_file_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/screens/branch_employee_statement_panel.dart';
import 'package:whizz_merchants/services/branch_employee_wallet_service.dart';
import 'package:whizz_merchants/services/branch_employee_access.dart';
import 'package:whizz_merchants/services/branch_device_service.dart';

BranchEmployeeAccess access({bool read = true, bool export = false}) =>
    BranchEmployeeAccess(
        api: BranchDeviceService(),
        token: 'device',
        session: 'staff',
        businessId: 'b',
        profile: {
          'capabilities': {
            'readWalletTransactions': read,
            'exportWallet': export
          }
        },
        lock: () async {});

class StatementApi extends BranchEmployeeWalletService {
  Completer<Map<String, dynamic>>? pending;
  bool fail = false;
  @override
  Future<Map<String, dynamic>> read(BranchEmployeeAccess access, String kind,
      {String? cursor,
      String? from,
      String? to,
      bool exportCsv = false}) async {
    if (pending != null) return pending!.future;
    if (fail) throw BranchDeviceException('MEMBERSHIP_REVOKED');
    return {
      'complete': true,
      'filename': 'branch-statement-2026-01-01-2026-01-02.csv',
      'csv': '\ufeffكـشف,فرع',
      'rowCount': 1,
      'entries': [
        {'amount': 750, 'description': 'حركة كشف تجريبية'}
      ]
    };
  }
}

class FileExporter extends StatementFileExportService {
  int calls = 0;
  bool saved = true;
  Completer<bool>? pending;
  @override
  Future<bool> save({required String filename, required String csv}) async {
    calls++;
    return pending == null ? saved : await pending!.future;
  }
}

void main() {
  test(
      'statement CSV requires live export permission locally and sends period with device credentials',
      () async {
    final requests = <http.Request>[];
    final api = BranchEmployeeWalletService(client: MockClient((r) async {
      requests.add(r);
      return http.Response(
          jsonEncode({
            'data': {'complete': true, 'entries': []}
          }),
          200);
    }));
    await expectLater(
        api.read(access(), 'statement',
            from: '2026-01-01', to: '2026-01-02', exportCsv: true),
        throwsA(isA<BranchDeviceException>()));
    expect(requests, isEmpty);
    await api.read(access(export: true), 'statement',
        from: '2026-01-01', to: '2026-01-02', exportCsv: true);
    expect(requests.single.url.queryParameters, {
      'businessId': 'b',
      'from': '2026-01-01',
      'to': '2026-01-02',
      'format': 'csv'
    });
    expect(requests.single.headers['Authorization'], 'Bearer device');
    expect(requests.single.headers['X-Staff-Session'], 'staff');
  });
  testWidgets(
      'statement controls follow read and export capabilities without owner or transfer controls',
      (tester) async {
    Widget panel(BranchEmployeeAccess a) => MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: BranchEmployeeStatementPanel(
                    access: a, api: BranchEmployeeWalletService()))));
    await tester.pumpWidget(panel(access(export: true)));
    expect(find.text('اختيار فترة الكشف'), findsOneWidget);
    expect(find.text('نسخ CSV'), findsOneWidget);
    await tester.pumpWidget(panel(access()));
    await tester.pump();
    expect(find.text('نسخ CSV'), findsNothing);
    expect(find.text('عرض الكشف'), findsOneWidget);
    await tester.pumpWidget(panel(access(read: false)));
    await tester.pump();
    expect(find.text('عرض الكشف'), findsNothing);
  });
  testWidgets(
      'statement refresh failure clears previously read financial entries',
      (tester) async {
    final api = StatementApi();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: BranchEmployeeStatementPanel(
                    access: access(), api: api)))));
    dynamic state = tester.state(find.byType(BranchEmployeeStatementPanel));
    state.period =
        DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 2));
    await state.load();
    await tester.pump();
    expect(find.textContaining('حركة كشف تجريبية'), findsOneWidget);
    api.fail = true;
    await state.load();
    await tester.pump();
    expect(find.textContaining('حركة كشف تجريبية'), findsNothing);
    expect(find.textContaining('تعذر إعداد الكشف'), findsOneWidget);
  });
  testWidgets('late statement response after access revocation is ignored',
      (tester) async {
    final api = StatementApi()..pending = Completer<Map<String, dynamic>>();
    Widget panel(BranchEmployeeAccess a) => MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: BranchEmployeeStatementPanel(access: a, api: api))));
    await tester.pumpWidget(panel(access()));
    dynamic state = tester.state(find.byType(BranchEmployeeStatementPanel));
    state.period =
        DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 2));
    final loading = state.load();
    await tester.pump();
    await tester.pumpWidget(panel(access(read: false)));
    await tester.pump();
    api.pending!.complete({
      'complete': true,
      'filename': 'branch-statement-2026-01-01-2026-01-02.csv',
      'csv': '\ufeffكـشف,فرع',
      'rowCount': 1,
      'entries': [
        {'amount': 999999, 'description': 'بيانات قديمة'}
      ]
    });
    await loading;
    await tester.pump();
    expect(find.textContaining('بيانات قديمة'), findsNothing);
    expect(state.statement, isNull);
  });
  testWidgets(
      'file save asks for a fresh CSV and reports success only after native acknowledgement',
      (tester) async {
    final api = StatementApi(),
        file = FileExporter()..pending = Completer<bool>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: BranchEmployeeStatementPanel(
                    access: access(export: true),
                    api: api,
                    fileExporter: file)))));
    dynamic state = tester.state(find.byType(BranchEmployeeStatementPanel));
    state.period =
        DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 2));
    final loading = state.load(export: true, saveFile: true);
    await tester.pump();
    expect(file.calls, 1);
    expect(find.text('تم حفظ ملف الكشف'), findsNothing);
    file.pending!.complete(true);
    await loading;
    await tester.pump();
    expect(find.text('تم حفظ ملف الكشف'), findsOneWidget);
  });
  testWidgets(
      'cancelled picker does not report success and late revoked CSV never opens file picker',
      (tester) async {
    final api = StatementApi(), file = FileExporter()..saved = false;
    Widget panel(BranchEmployeeAccess a) => MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: BranchEmployeeStatementPanel(
                    access: a, api: api, fileExporter: file))));
    await tester.pumpWidget(panel(access(export: true)));
    dynamic state = tester.state(find.byType(BranchEmployeeStatementPanel));
    state.period =
        DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 2));
    await state.load(export: true, saveFile: true);
    await tester.pump();
    expect(file.calls, 1);
    expect(find.text('تم حفظ ملف الكشف'), findsNothing);
    api.pending = Completer<Map<String, dynamic>>();
    final loading = state.load(export: true, saveFile: true);
    await tester.pump();
    await tester.pumpWidget(panel(access(export: false)));
    await tester.pump();
    api.pending!.complete({
      'complete': true,
      'filename': 'branch-statement-2026-01-01-2026-01-02.csv',
      'csv': 'old'
    });
    await loading;
    await tester.pump();
    expect(file.calls, 1);
    expect(state.statement, isNull);
  });
}
