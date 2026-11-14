import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/services/branch_device_service.dart';
import 'package:whizz_merchants/services/person_onboarding_service.dart';
import 'package:whizz_merchants/screens/branch_device_tasks.dart';
import 'package:whizz_merchants/screens/staff_product_activity_screen.dart';

class ProductApi extends BranchDeviceService {
  final writes = <Map<String, dynamic>>[];
  final methods = <String?>[];
  bool failFirst = false;
  @override
  Future<Map<String, dynamic>> operation(String token, String path,
      {String? session, Map<String, dynamic>? body, String? method}) async {
    if (body != null) {
      writes.add(body);
      methods.add(method);
      if (failFirst) {
        failFirst = false;
        throw BranchDeviceException('UNAVAILABLE');
      }
    }
    if (path == 'categories')
      return {
        'categories': [
          {'categoryId': 'c', 'categoryName': 'وجبات'}
        ]
      };
    return {
      'products': [
        {'productId': 'p', 'name': 'وجبة', 'price': 3500, 'isAvailable': true}
      ]
    };
  }
}

Widget tasks(ProductApi api, {bool permitted = true}) => MaterialApp(
    home: Scaffold(
        body: SingleChildScrollView(
            child: BranchDeviceTasks(
                api: api,
                token: 'device',
                session: 'staff',
                businessId: 'b',
                role: 'central-manager',
                capabilities: {
                  'readMenu': true,
                  'editMenu': false,
                  'createProduct': permitted,
                  'deleteProduct': permitted
                },
                initialTab: 'menu',
                showTabs: false))));
void main() {
  testWidgets(
      'creation keeps the form and same request after a failure; sends POST with category',
      (t) async {
    final api = ProductApi()..failFirst = true;
    await t.pumpWidget(tasks(api));
    await t.pumpAndSettle();
    await t.tap(find.text('إضافة منتج'));
    await t.pumpAndSettle();
    await t.enterText(
        find.widgetWithText(TextField, 'اسم المنتج'), 'وجبة جديدة');
    await t.enterText(find.widgetWithText(TextField, 'السعر بالدينار'), '4200');
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('وجبات').last);
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('إضافة'));
    await t.tap(find.text('إضافة'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'اسم المنتج'), findsOneWidget);
    await t.tap(find.text('إضافة'));
    await t.pumpAndSettle();
    expect(api.methods, ['POST', 'POST']);
    expect(api.writes.first['requestId'], api.writes.last['requestId']);
    expect(api.writes.last['categoryId'], 'c');
    expect(api.writes.last['businessId'], 'b');
    expect(api.writes.last['price'], 4200);
  });
  testWidgets(
      'deletion needs confirmation; a read-only employee sees neither mutation',
      (t) async {
    final api = ProductApi();
    await t.pumpWidget(tasks(api));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('حذف المنتج'));
    await t.pumpAndSettle();
    await t.tap(find.text('رجوع'));
    await t.pumpAndSettle();
    expect(api.writes, isEmpty);
    await t.tap(find.byTooltip('حذف المنتج'));
    await t.pumpAndSettle();
    await t.tap(find.text('حذف'));
    await t.pumpAndSettle();
    expect(api.methods, ['DELETE']);
    await t.pumpWidget(tasks(api, permitted: false));
    await t.pumpAndSettle();
    expect(find.text('إضافة منتج'), findsNothing);
    expect(find.byTooltip('حذف المنتج'), findsNothing);
  });
  test('device transport accepts creation HTTP 201 and sends no person token',
      () async {
    late http.Request sent;
    final api = BranchDeviceService(client: MockClient((request) async {
      sent = request;
      return http.Response('{"success":true}', 201);
    }));
    await api.operation('device-only', 'products',
        session: 'staff-only', method: 'POST', body: {'name': 'منتج'});
    expect(sent.method, 'POST');
    expect(sent.headers['Authorization'], 'Bearer device-only');
    expect(sent.headers['X-Staff-Session'], 'staff-only');
    expect(jsonDecode(sent.body)['name'], 'منتج');
  });
  testWidgets(
      'owner activity fetches selected employee and follows an empty page cursor',
      (t) async {
    final paths = <String>[];
    final api = ActivityApi(paths);
    await t.pumpWidget(MaterialApp(
        home: StaffProductActivityScreen(
            businessId: 'b', subjectId: 'employee', service: api)));
    await t.pumpAndSettle();
    expect(find.text('لا توجد عمليات مسجلة.'), findsNothing);
    await t.tap(find.text('المزيد من العمليات'));
    await t.pumpAndSettle();
    expect(Uri.splitQueryString(paths.first.split('?').last)['subjectId'],
        'employee');
    expect(
        Uri.splitQueryString(paths.last.split('?').last)['cursor'], 'page-2');
    expect(find.textContaining('منتج تجريبي'), findsOneWidget);
  });
}

class ActivityApi extends PersonOnboardingService {
  final List<String> paths;
  ActivityApi(this.paths);
  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    paths.add(path);
    if (paths.length == 1) return {'items': [], 'nextCursor': 'page-2'};
    return {
      'items': [
        {
          'action': 'MENU_PRODUCT_CREATED',
          'actorName': 'أحمد',
          'after': {'name': 'منتج تجريبي', 'price': 4200},
          'createdAt': '2026-10-15T12:00:00Z'
        }
      ]
    };
  }
}
