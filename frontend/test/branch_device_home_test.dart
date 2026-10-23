import '../lib/l10n/app_localizations.dart';
import '../lib/screens/orders_page.dart';
import '../lib/screens/dashboards/business_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/branch_device_home_screen.dart';
import '../lib/services/branch_device_service.dart';

class DeviceApi extends BranchDeviceService {
  final calls = <String>[];
  bool revoked = false;
  String role = 'MANAGER';
  @override
  Future<Map<String, dynamic>> call(String token, Map<String, dynamic> body,
      {String? session}) async {
    calls.add(body['action']);
    if (revoked) throw BranchDeviceException('MEMBERSHIP_REVOKED');
    switch (body['action']) {
      case 'reception':
        return {
          'businessName': 'فتوش',
          'device': {'name': 'جهاز المطبخ'},
          'staff': [
            {
              'subjectId': 'employee',
              'displayName': 'أحمد',
              'role': 'MANAGER',
              'pinReady': true
            }
          ]
        };
      case 'unlock':
        return {
          'staffSession': 'individual',
          'expiresAt': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 120
        };
      case 'profile':
        return {
          'staff': {'displayName': 'أحمد', 'role': role},
          'business': {'description': 'الوصف التشغيلي'},
          'capabilities': {
            'editHours': role == 'MANAGER',
            'editMenu': role == 'MANAGER'
          }
        };
      case 'lock':
        return {'success': true};
    }
    throw StateError('Unexpected action');
  }

  @override
  Future<Map<String, dynamic>> operation(String token, String path,
      {String? session, Map<String, dynamic>? body, String? method}) async {
    calls.add(path);
    return {'orders': [], 'products': []};
  }
}

Future<void> open(WidgetTester t, DeviceApi api) async {
  await t.pumpWidget(ProviderScope(
      child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BranchDeviceHomeScreen(
              device: const {'businessId': 'b', 'deviceToken': 'scoped-device'},
              service: api))));
  await t.pumpAndSettle();
}

Future<void> unlock(WidgetTester t) async {
  await t.tap(find.text('أحمد'));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField), '147258');
  await t.tap(find.text('فتح المهام'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('lock keeps device reception and hides individual tasks',
      (t) async {
    final api = DeviceApi();
    await open(t, api);
    expect(find.text('القائمة'), findsNothing);
    await unlock(t);
    expect(find.byTooltip('قفل مهامي'), findsOneWidget);
    expect(find.byType(BusinessDashboard), findsOneWidget);
    expect(find.byType(OrdersPage), findsOneWidget);
    expect(find.text('المنتجات'), findsOneWidget);
    await t.tap(find.text('الإعدادات'));
    await t.pumpAndSettle();
    expect(find.text('ساعات العمل'), findsOneWidget);
    expect(find.text('الموظفون والصلاحيات'), findsNothing);
    expect(find.text('بياناتي الشخصية'), findsNothing);
    await t.tap(find.text('قفل مهامي'));
    await t.pumpAndSettle();
    expect(find.text('من سيبدأ العمل؟'), findsOneWidget);
    expect(find.text('القائمة'), findsNothing);
    expect(find.text('فتوش'), findsOneWidget);
    expect(api.calls.contains('lock'), true);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
  testWidgets('reception uses original orders with no menu or hours settings',
      (t) async {
    final api = DeviceApi()..role = 'RECEPTION';
    await open(t, api);
    await unlock(t);
    expect(find.byType(OrdersPage), findsOneWidget);
    expect(find.text('المنتجات'), findsNothing);
    await t.tap(find.text('الإعدادات'));
    await t.pumpAndSettle();
    expect(find.text('ساعات العمل'), findsNothing);
    expect(find.text('قفل مهامي'), findsOneWidget);
    expect(find.text('المحفظة'), findsNothing);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
  testWidgets('timeout hides tasks while device stays available', (t) async {
    final api = DeviceApi();
    await open(t, api);
    await unlock(t);
    await t.pump(const Duration(seconds: 121));
    await t.pumpAndSettle();
    expect(find.text('قفل مهامي'), findsNothing);
    expect(find.text('فتوش'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
  testWidgets('revocation clears employee tasks during synchronization',
      (t) async {
    final api = DeviceApi();
    await open(t, api);
    await unlock(t);
    api.revoked = true;
    await t.pump(const Duration(seconds: 16));
    await t.pumpAndSettle();
    expect(find.text('القائمة'), findsNothing);
    expect(find.textContaining('سُحبت'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
