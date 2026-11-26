import 'dart:convert';
import 'dart:async';
import 'package:whizz_merchants/services/statement_file_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/widgets/merchant_sales_report_summary.dart';
import 'package:whizz_merchants/screens/branch_employee_statement_panel.dart';
import 'package:whizz_merchants/services/branch_employee_wallet_service.dart';
import 'package:whizz_merchants/services/branch_employee_access.dart';
import 'package:whizz_merchants/services/branch_device_service.dart';

final summary = {
  'status': 'AVAILABLE',
  'orderCount': 3,
  'completedOrderCount': 2,
  'totalsSubunits': {'goods': 20098, 'discount': 1000, 'checkout': 22098}
};
BranchEmployeeAccess access(bool allowed,
        {bool export = false, bool walletExport = false}) =>
    BranchEmployeeAccess(
        api: BranchDeviceService(),
        token: 'device',
        session: 'staff',
        businessId: 'b',
        profile: {
          'capabilities': {
            'readSalesReports': allowed,
            'exportSalesReports': export,
            'exportWallet': walletExport
          }
        },
        lock: () async {});

class SalesFileExporter extends StatementFileExportService {
  int calls = 0;
  String? filename;
  Completer<bool>? pending;
  @override
  Future<bool> save({required String filename, required String csv}) async {
    calls++;
    this.filename = filename;
    return pending == null ? true : await pending!.future;
  }
}

void main() {
  testWidgets(
      'sales display converts integer subunits once and labels original invoices rather than profit',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MerchantSalesReportSummary(summary: summary))));
    expect(find.text('قيمة السلع قبل الخصومات: 20.098 د.ع'), findsOneWidget);
    expect(
        find.text('إجمالي الفواتير شامل الرسوم: 22.098 د.ع'), findsOneWidget);
    expect(find.textContaining('لا تثبت التحصيل أو الربح'), findsOneWidget);
  });
  testWidgets('unproven completed price hides every monetary subtotal',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MerchantSalesReportSummary(summary: {
      ...summary,
      'status': 'UNAVAILABLE',
      'unclassifiedCompletedCount': 1
    }))));
    expect(find.textContaining('20.098'), findsNothing);
    expect(find.textContaining('لا تُعرض مجاميع جزئية'), findsOneWidget);
  });
  testWidgets(
      'report-only employee uses only the sales endpoint and cannot export wallet data',
      (tester) async {
    final requests = <http.Request>[];
    final api = BranchEmployeeWalletService(client: MockClient((r) async {
      requests.add(r);
      return http.Response(
          jsonEncode({
            'data': {'complete': true, 'summary': summary}
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: BranchEmployeeStatementPanel(
                    access: access(true), api: api, sales: true)))));
    dynamic state = tester.state(find.byType(BranchEmployeeStatementPanel));
    state.period =
        DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 2));
    await state.load();
    await tester.pump();
    expect(requests.single.url.path,
        endsWith('/wallet/branch-device/sales-report'));
    expect(requests.single.headers['Authorization'], 'Bearer device');
    expect(find.textContaining('20.098'), findsOneWidget);
    expect(find.text('حفظ ملف CSV'), findsNothing);
    expect(find.text('نسخ CSV'), findsNothing);
    await expectLater(
        api.read(access(false), 'sales-report',
            from: '2026-01-01', to: '2026-01-02'),
        throwsA(isA<BranchDeviceException>()));
  });
  test(
      'sales CSV client requires report export instead of wallet export and requests a fresh CSV',
      () async {
    final requests = <http.Request>[];
    final api = BranchEmployeeWalletService(client: MockClient((r) async {
      requests.add(r);
      return http.Response(
          jsonEncode({
            'data': {'complete': true, 'csv': 'csv'}
          }),
          200);
    }));
    await expectLater(
        api.read(access(true, walletExport: true), 'sales-report',
            from: '2026-01-01', to: '2026-01-02', exportCsv: true),
        throwsA(isA<BranchDeviceException>()));
    expect(requests, isEmpty);
    await api.read(access(true, export: true), 'sales-report',
        from: '2026-01-01', to: '2026-01-02', exportCsv: true);
    expect(requests.single.url.queryParameters['format'], 'csv');
    expect(requests.single.headers['X-Staff-Session'], 'staff');
  });
  testWidgets(
      'sales file save uses the report filename and waits for native acknowledgement',
      (tester) async {
    final requests = <http.Request>[];
    final file = SalesFileExporter()..pending = Completer<bool>();
    final api = BranchEmployeeWalletService(client: MockClient((r) async {
      requests.add(r);
      return http.Response(
          jsonEncode({
            'data': {
              'complete': true,
              'summary': summary,
              'csv': 'csv',
              'filename': 'branch-sales-report-2026-01-01-2026-01-02.csv'
            }
          }),
          200);
    }));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: BranchEmployeeStatementPanel(
                    access: access(true, export: true),
                    api: api,
                    sales: true,
                    fileExporter: file)))));
    dynamic state = tester.state(find.byType(BranchEmployeeStatementPanel));
    state.period =
        DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 2));
    final loading = state.load(export: true, saveFile: true);
    await tester.pump();
    expect(requests.single.url.queryParameters['format'], 'csv');
    expect(file.filename, 'branch-sales-report-2026-01-01-2026-01-02.csv');
    expect(find.text('تم حفظ ملف التقرير'), findsNothing);
    file.pending!.complete(true);
    await loading;
    await tester.pump();
    expect(find.text('تم حفظ ملف التقرير'), findsOneWidget);
  });
  testWidgets(
      'revoking report export discards late CSV and never opens native saving',
      (tester) async {
    final pending = Completer<http.Response>(), file = SalesFileExporter();
    final api =
        BranchEmployeeWalletService(client: MockClient((r) => pending.future));
    Widget screen(bool export) => MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: BranchEmployeeStatementPanel(
                    access: access(true, export: export),
                    api: api,
                    sales: true,
                    fileExporter: file))));
    await tester.pumpWidget(screen(true));
    dynamic state = tester.state(find.byType(BranchEmployeeStatementPanel));
    state.period =
        DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 2));
    final loading = state.load(export: true, saveFile: true);
    await tester.pump();
    await tester.pumpWidget(screen(false));
    await tester.pump();
    pending.complete(http.Response(
        jsonEncode({
          'data': {
            'complete': true,
            'csv': 'old',
            'filename': 'branch-sales-report-2026-01-01-2026-01-02.csv',
            'summary': summary
          }
        }),
        200));
    await loading;
    await tester.pump();
    expect(file.calls, 0);
    expect(state.statement, isNull);
    expect(find.text('حفظ ملف CSV'), findsNothing);
  });
}
