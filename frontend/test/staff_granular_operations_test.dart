import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/models/order.dart';
import 'package:whizz_merchants/l10n/app_localizations.dart';
import 'package:whizz_merchants/widgets/order_card.dart';
import 'package:whizz_merchants/screens/branch_device_tasks.dart';
import 'package:whizz_merchants/services/branch_device_service.dart';

class GranularApi extends BranchDeviceService {
  final writes = <Map<String, dynamic>>[];
  bool rejectEdits = false;
  Completer<Map<String, dynamic>>? pendingEdit;
  @override
  Future<Map<String, dynamic>> operation(String token, String path,
      {String? session, Map<String, dynamic>? body, String? method}) async {
    if (body != null) {
      writes.add(body);
      if (rejectEdits) throw BranchDeviceException('VERSION_OR_STATE_CONFLICT');
      if (pendingEdit != null) return pendingEdit!.future;
    }
    return {
      'products': [
        {
          'productId': 'p',
          'name': 'وجبة',
          'description': 'وصف',
          'price': 3500,
          'isAvailable': true
        }
      ],
      'workingHours': {}
    };
  }
}

Widget tasks(GranularApi api, Map<String, dynamic> caps,
        {String tab = 'menu', String session = 'staff'}) =>
    MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
            body: SingleChildScrollView(
                child: BranchDeviceTasks(
                    key: ValueKey(tab),
                    api: api,
                    token: 'device',
                    session: session,
                    businessId: 'b',
                    role: 'custom',
                    capabilities: caps,
                    initialTab: tab,
                    showTabs: false))));
void main() {
  testWidgets(
      'late edit acknowledgement does not show success for a changed staff session',
      (t) async {
    final api = GranularApi()..pendingEdit = Completer<Map<String, dynamic>>();
    final caps = {'readMenu': true, 'editMenu': true};
    await t.pumpWidget(tasks(api, caps));
    await t.pumpAndSettle();
    await t.tap(find.text('وجبة'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'السعر بالدينار'), '4200');
    await t.tap(find.text('حفظ'));
    await t.pump();
    await t.pumpWidget(tasks(api, caps, session: 'different-staff'));
    await t.pump();
    api.pendingEdit!.complete({});
    await t.pumpAndSettle();
    expect(api.writes.length, 1);
    expect(find.text('تم الحفظ على الخادم.'), findsNothing);
    expect(find.text('تعديل المنتج'), findsNothing);
  });

  testWidgets('invalid price remains in the editor without sending a write',
      (t) async {
    final api = GranularApi();
    await t.pumpWidget(tasks(api, {'readMenu': true, 'editMenu': true}));
    await t.pumpAndSettle();
    await t.tap(find.text('وجبة'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'السعر بالدينار'), '0');
    await t.tap(find.text('حفظ'));
    await t.pumpAndSettle();
    expect(api.writes, isEmpty);
    expect(find.text('تعديل المنتج'), findsOneWidget);
    expect(find.text('أدخل سعرًا صحيحًا أكبر من صفر.'), findsOneWidget);
    await t.tap(find.text('رجوع'));
    await t.pumpAndSettle();
    expect(api.writes, isEmpty);
  });
  testWidgets(
      'changing a failed edit creates a distinct attempt while retaining its fields',
      (t) async {
    final api = GranularApi()..rejectEdits = true;
    await t.pumpWidget(tasks(api, {'readMenu': true, 'editMenu': true}));
    await t.pumpAndSettle();
    await t.tap(find.text('وجبة'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'السعر بالدينار'), '4200');
    await t.tap(find.text('حفظ'));
    await t.pumpAndSettle();
    final first = api.writes.single['requestId'];
    await t.enterText(find.widgetWithText(TextField, 'السعر بالدينار'), '4300');
    await t.tap(find.text('حفظ'));
    await t.pumpAndSettle();
    expect(api.writes.length, 2);
    expect(api.writes.last['requestId'], isNot(first));
    expect(api.writes.last['price'], 4300);
    expect(find.text('تعديل المنتج'), findsOneWidget);
    await t.tap(find.text('رجوع'));
    await t.pumpAndSettle();
  });
  testWidgets(
      'edit waits for server acknowledgement and disables duplicate submissions',
      (t) async {
    final api = GranularApi()..pendingEdit = Completer<Map<String, dynamic>>();
    await t.pumpWidget(tasks(api, {'readMenu': true, 'editMenu': true}));
    await t.pumpAndSettle();
    await t.tap(find.text('وجبة'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'السعر بالدينار'), '4200');
    await t.tap(find.text('حفظ'));
    await t.pump();
    expect(find.text('تعديل المنتج'), findsOneWidget);
    expect(find.text('تم الحفظ على الخادم.'), findsNothing);
    expect(
        t
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'حفظ'))
            .onPressed,
        isNull);
    await t.tap(find.text('حفظ'));
    await t.pump();
    expect(api.writes.length, 1);
    api.pendingEdit!.complete({});
    await t.pumpAndSettle();
    expect(find.text('تعديل المنتج'), findsNothing);
    expect(find.text('تم الحفظ على الخادم.'), findsOneWidget);
  });

  testWidgets('operational employee sees both acceptance and rejection',
      (t) async {
    final updates = <OrderStatus>[];
    final order = Order.fromJson({
      'orderId': 'o',
      'status': 'pending',
      'items': [],
      'totalAmount': 3500,
      'createdAt': '2026-10-15T00:00:00Z'
    });
    await t.pumpWidget(ProviderScope(
        child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
                body: SingleChildScrollView(
                    child: OrderCard(
                        order: order,
                        onOrderUpdated: (_, s) => updates.add(s),
                        canUpdateStatus: (s) =>
                            s == OrderStatus.confirmed ||
                            s == OrderStatus.cancelled))))));
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    await t.ensureVisible(find.text('Accept'));
    await t.tap(find.text('Accept'));
    expect(updates, [OrderStatus.confirmed]);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'price-only editor hides name, description and availability and sends price only',
      (t) async {
    final api = GranularApi();
    await t.pumpWidget(tasks(api, {
      'readMenu': true,
      'editMenu': true,
      'editProductInfo': false,
      'editProductPrice': true,
      'editProductAvailability': false
    }));
    await t.pumpAndSettle();
    await t.tap(find.text('وجبة'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'اسم المنتج'), findsNothing);
    expect(find.widgetWithText(TextField, 'وصف المنتج'), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    await t.enterText(find.widgetWithText(TextField, 'السعر بالدينار'), '4200');
    await t.tap(find.text('حفظ'));
    await t.pumpAndSettle();
    expect(api.writes.single['requestId'], isA<String>());
    expect({...api.writes.single}..remove('requestId'),
        {'businessId': 'b', 'price': 4200});
    await t.pump(const Duration(seconds: 2));
  });
  testWidgets('editing retry retains its request after failure', (t) async {
    final api = GranularApi()..rejectEdits = true;
    await t.pumpWidget(tasks(api, {
      'readMenu': true,
      'editMenu': true,
      'editProductInfo': false,
      'editProductPrice': true,
      'editProductAvailability': false
    }));
    await t.pumpAndSettle();
    await t.tap(find.text('وجبة'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'اسم المنتج'), findsNothing);
    expect(find.widgetWithText(TextField, 'وصف المنتج'), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    await t.enterText(find.widgetWithText(TextField, 'السعر بالدينار'), '4200');
    await t.tap(find.text('حفظ'));
    await t.pumpAndSettle();
    final requestId = api.writes.single['requestId'];
    api.rejectEdits = false;
    expect(find.text('تعديل المنتج'), findsOneWidget);
    expect(
        t
            .widget<TextField>(find.widgetWithText(TextField, 'السعر بالدينار'))
            .controller!
            .text,
        '4200');
    await t.tap(find.text('حفظ'));
    await t.pumpAndSettle();
    expect(api.writes.length, 2);
    expect(api.writes.last['requestId'], requestId);
    await t.pump(const Duration(seconds: 2));
  });
  testWidgets('reading products and hours exposes no edit or save actions',
      (t) async {
    final api = GranularApi();
    await t.pumpWidget(tasks(api, {'readMenu': true, 'editMenu': false}));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    await t.tap(find.text('وجبة'));
    await t.pump();
    expect(find.text('تعديل المنتج'), findsNothing);
    await t.pumpWidget(
        tasks(api, {'readHours': true, 'editHours': false}, tab: 'hours'));
    await t.pumpAndSettle();
    expect(find.text('الأحد'), findsOneWidget);
    expect(find.text('حفظ أسبوع العمل'), findsNothing);
    expect(api.writes, isEmpty);
  });
}
