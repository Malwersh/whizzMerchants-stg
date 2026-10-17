import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/services/branch_device_service.dart';
import 'package:whizz_merchants/services/branch_employee_access.dart';
import 'package:whizz_merchants/screens/branch_employee_discounts_screen.dart';
import 'package:whizz_merchants/screens/dashboards/business_dashboard.dart';

const row = {
  'discountId': 'd',
  'title': 'عرض الفرع',
  'type': 'percentage',
  'value': 15,
  'description': 'وصف',
  'minimum_order_amount': 1000,
  'valid_from': '2099-01-01T00:00:00.000Z',
  'valid_to': '2099-01-31T23:59:59.999Z',
  'status': 'inactive',
  'editable': true,
  'revision': 'base'
};

class DiscountsApi extends BranchDeviceService {
  final requests = <Map<String, dynamic>>[];
  Future<Map<String, dynamic>> Function(Map<String, dynamic>)? respond;
  @override
  Future<Map<String, dynamic>> call(String token, Map<String, dynamic> body,
      {String? session}) async {
    requests.add({'token': token, 'session': session, ...body});
    return respond != null
        ? await respond!(body)
        : body['action'] == 'discounts_list'
            ? {
                'discounts': [row]
              }
            : {'success': true};
  }
}

BranchEmployeeAccess access(DiscountsApi api,
        {Map<String, dynamic>? caps,
        String session = 'employee',
        String branch = 'b'}) =>
    BranchEmployeeAccess(
        api: api,
        token: 'device',
        session: session,
        businessId: branch,
        profile: {
          'business': {'businessName': 'فرع'},
          'staff': {'role': 'CUSTOM', 'permissionSchema': 2},
          'capabilities': caps ??
              {
                'readDiscounts': true,
                'createDiscounts': true,
                'editDiscounts': true,
                'activateDiscounts': true,
                'deleteDiscounts': true
              }
        },
        lock: () async {});
Widget app(BranchEmployeeAccess a) =>
    MaterialApp(home: Scaffold(body: BranchEmployeeDiscountsScreen(access: a)));
void main() {
  testWidgets(
      'read-only discounts never offer employee mutations or owner transport',
      (t) async {
    final api = DiscountsApi();
    await t.pumpWidget(app(access(api, caps: {'readDiscounts': true})));
    await t.pumpAndSettle();
    expect(find.text('عرض الفرع'), findsOneWidget);
    expect(find.text('إضافة خصم'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(api.requests.single,
        {'token': 'device', 'session': 'employee', 'action': 'discounts_list'});
  });
  testWidgets('advanced discounts are visible without editable actions',
      (t) async {
    final api = DiscountsApi()
      ..respond = (_) async => {
            'discounts': [
              {...row, 'type': 'buyXGetY', 'editable': false}
            ]
          };
    await t.pumpWidget(app(access(api)));
    await t.pumpAndSettle();
    expect(find.text('للقراءة فقط'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });
  testWidgets(
      'create retains the form and request identifier after an uncertain failure',
      (t) async {
    var reject = true;
    final api = DiscountsApi()
      ..respond = (b) async {
        if (b['action'] == 'discounts_list') return {'discounts': []};
        if (reject) throw BranchDeviceException('UNAVAILABLE');
        return {'success': true};
      };
    await t.pumpWidget(app(access(api)));
    await t.pumpAndSettle();
    await t.tap(find.text('إضافة خصم'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'اسم الخصم'), 'عرض');
    await t.enterText(
        find.widgetWithText(TextField, 'النسبة المئوية (حتى 100)'), '15');
    await t.tap(find.text('حفظ'));
    await t.pumpAndSettle();
    final first = api.requests.last;
    expect(find.widgetWithText(TextField, 'اسم الخصم'), findsOneWidget);
    expect(
        t
            .widget<TextField>(find.widgetWithText(TextField, 'اسم الخصم'))
            .controller!
            .text,
        'عرض');
    reject = false;
    await t.tap(find.text('حفظ'));
    await t.pumpAndSettle();
    final writes =
        api.requests.where((b) => b['action'] == 'discounts_create').toList();
    expect(writes.length, 2);
    expect(writes.last['requestId'], first['requestId']);
    expect(find.text('تم حفظ الخصم على الخادم.'), findsOneWidget);
    expect(writes.last.containsKey('ownerId'), false);
    expect(writes.last['data']['type'], 'percentage');
  });
  testWidgets(
      'activation is confirmed, uses explicit desired state and waits for acknowledgement',
      (t) async {
    final pending = Completer<Map<String, dynamic>>();
    final api = DiscountsApi()
      ..respond = (b) async => b['action'] == 'discounts_list'
          ? {
              'discounts': [row]
            }
          : await pending.future;
    await t.pumpWidget(app(access(api)));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('تفعيل الخصم'));
    await t.pumpAndSettle();
    expect(api.requests.length, 1);
    await t.tap(find.text('تأكيد'));
    await t.pump();
    expect(api.requests.last['action'], 'discounts_status');
    expect(api.requests.last['active'], true);
    expect(api.requests.last['baseRevision'], 'base');
    expect(find.text('تم حفظ التغيير على الخادم.'), findsNothing);
    pending.complete({'success': true});
    await t.pumpAndSettle();
    expect(find.text('تم حفظ التغيير على الخادم.'), findsOneWidget);
  });
  testWidgets('cancelled deletion never sends a request', (t) async {
    final api = DiscountsApi();
    await t.pumpWidget(app(access(api)));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('حذف الخصم'));
    await t.pumpAndSettle();
    await t.tap(find.text('رجوع'));
    await t.pumpAndSettle();
    expect(api.requests.length, 1);
  });
  testWidgets(
      'filtered empty pages continue and failed revalidation removes old discounts',
      (t) async {
    var failed = false;
    final api = DiscountsApi()
      ..respond = (b) async {
        if (failed) throw BranchDeviceException('PERMISSION_REQUIRED');
        return b['cursor'] == null
            ? {'discounts': [], 'nextCursor': 'page'}
            : {
                'discounts': [row]
              };
      };
    await t.pumpWidget(app(access(api)));
    await t.pumpAndSettle();
    expect(find.text('لا توجد خصومات.'), findsNothing);
    await t.tap(find.text('المزيد من الخصومات'));
    await t.pumpAndSettle();
    expect(api.requests.last['cursor'], 'page');
    expect(find.text('عرض الفرع'), findsOneWidget);
    failed = true;
    await t.tap(find.byTooltip('تحديث'));
    await t.pumpAndSettle();
    expect(find.text('عرض الفرع'), findsNothing);
    expect(find.text('لا توجد خصومات.'), findsNothing);
  });
  testWidgets(
      'session change closes an old editor and ignores its late save acknowledgement',
      (t) async {
    final pending = Completer<Map<String, dynamic>>();
    final api = DiscountsApi()
      ..respond = (b) async => b['action'] == 'discounts_list'
          ? {
              'discounts': [row]
            }
          : await pending.future;
    await t.pumpWidget(app(access(api)));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('تعديل الخصم'));
    await t.pumpAndSettle();
    await t.enterText(
        find.widgetWithText(TextField, 'النسبة المئوية (حتى 100)'), '20');
    await t.tap(find.text('حفظ'));
    await t.pump();
    await t.pumpWidget(app(access(api, session: 'next-employee')));
    await t.pumpAndSettle();
    expect(find.text('تعديل الخصم'), findsNothing);
    pending.complete({'success': true});
    await t.pumpAndSettle();
    expect(find.text('تم حفظ الخصم على الخادم.'), findsNothing);
    expect(
        api.requests
            .where((r) => r['action'] == 'discounts_update')
            .single['session'],
        'employee');
  });
  testWidgets(
      'dashboard opens discounts for their grant without owner API initialization',
      (t) async {
    final api = DiscountsApi();
    await t.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: BusinessDashboard(
                employeeAccess: access(api, caps: {'readDiscounts': true})))));
    await t.pumpAndSettle();
    expect(find.text('الخصومات'), findsOneWidget);
    expect(find.text('عرض الفرع'), findsOneWidget);
    expect(find.text('المنتجات'), findsNothing);
    expect(api.requests.single['action'], 'discounts_list');
  });
}
