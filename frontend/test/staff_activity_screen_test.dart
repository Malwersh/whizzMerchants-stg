import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/services/person_onboarding_service.dart';
import 'package:whizz_merchants/screens/staff_product_activity_screen.dart';

class ActivityApi extends PersonOnboardingService {
  final requests = <Uri>[];
  Future<Map<String, dynamic>> Function(Uri)? respond;
  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    final uri = Uri.parse(path);
    requests.add(uri);
    return respond == null
        ? {
            'items': [statusEvent]
          }
        : await respond!(uri);
  }
}

final statusEvent = <String, dynamic>{
  'action': 'BRANCH_STATUS_CHANGED',
  'actorName': 'أحمد',
  'roleName': 'مدير',
  'createdAt': '2026-10-15T01:00:00Z',
  'result': 'SUCCEEDED',
  'before': {'acceptingOrders': false},
  'after': {'acceptingOrders': true},
};
Widget app(ActivityApi api,
        {String branch = 'b', String? subject = 'employee'}) =>
    MaterialApp(
        home: StaffProductActivityScreen(
            businessId: branch, subjectId: subject, service: api));
void main() {
  testWidgets(
      'transfer completion and code request are distinguished in the owner history',
      (t) async {
    final api = ActivityApi()
      ..respond = (_) async => {
            'items': [
              {
                ...statusEvent,
                'action': 'MERCHANT_STAFF_TRANSFER_COMPLETED',
                'entityId': 'transfer-reference',
                'amount': 5000,
                'currency': 'IQD',
                'transferStatus': 'COMPLETED'
              },
              {
                ...statusEvent,
                'action': 'MERCHANT_STAFF_TRANSFER_VERIFICATION_REQUESTED',
                'entityId': 'code-request'
              }
            ]
          };
    await t.pumpWidget(app(api));
    await t.pumpAndSettle();
    expect(find.textContaining('المبلغ: 5000 د.ع'), findsOneWidget);
    expect(find.textContaining('حالة التحويل: مكتمل'), findsOneWidget);
    await t.drag(find.byType(ListView), const Offset(0, -450));
    await t.pumpAndSettle();
    expect(
        find.textContaining('لا يثبت هذا الحدث تسليم الرسالة'), findsOneWidget);
  });

  testWidgets(
      'discount history displays business terms and status before and after',
      (t) async {
    final api = ActivityApi()
      ..respond = (_) async => {
            'items': [
              {
                ...statusEvent,
                'action': 'DISCOUNT_UPDATED',
                'entityId': 'discount-1',
                'before': {
                  'title': 'عرض',
                  'type': 'percentage',
                  'value': 10,
                  'status': 'inactive'
                },
                'after': {
                  'title': 'عرض',
                  'type': 'percentage',
                  'value': 15,
                  'status': 'active'
                },
              }
            ]
          };
    await t.pumpWidget(app(api));
    await t.pumpAndSettle();
    expect(find.text('تعديل خصم'), findsOneWidget);
    expect(find.textContaining('القيمة قبل: 10؛ بعد: 15'), findsOneWidget);
    expect(
        find.textContaining('الحالة قبل: متوقف؛ بعد: مفعّل'), findsOneWidget);
    expect(find.textContaining('المرجع: discount-1'), findsOneWidget);
    expect(find.textContaining('السعر:'), findsNothing);
  });

  testWidgets(
      'hours history shows changed days and distinguishes missing from closed',
      (t) async {
    final api = ActivityApi()
      ..respond = (_) async => {
            'items': [
              {
                ...statusEvent,
                'action': 'BRANCH_HOURS_CHANGED',
                'entityId': 'b',
                'before': {
                  'days': [
                    {
                      'weekday': 'Monday',
                      'opening': '09:00',
                      'closing': '18:00',
                      'isClosed': false
                    },
                    {'weekday': 'Tuesday'}
                  ]
                },
                'after': {
                  'days': [
                    {
                      'weekday': 'Monday',
                      'opening': 'closed',
                      'closing': 'closed',
                      'isClosed': true
                    },
                    {
                      'weekday': 'Tuesday',
                      'opening': '10:00',
                      'closing': '19:00',
                      'isClosed': false
                    }
                  ]
                },
              }
            ]
          };
    await t.pumpWidget(app(api));
    await t.pumpAndSettle();
    expect(find.text('تعديل ساعات العمل'), findsOneWidget);
    expect(find.textContaining('الاثنين قبل: 09:00 — 18:00؛ بعد: مغلق'),
        findsOneWidget);
    expect(find.textContaining('الثلاثاء قبل: غير مسجل؛ بعد: 10:00 — 19:00'),
        findsOneWidget);
    expect(find.textContaining('السعر:'), findsNothing);
    expect(find.textContaining('أحمد'), findsOneWidget);
  });
  testWidgets(
      'financial activity labels all supported reads and exports without money contents',
      (t) async {
    final api = ActivityApi()
      ..respond = (_) async => {
            'items': [
              for (final action in [
                'MERCHANT_STAFF_BALANCE_READ',
                'MERCHANT_STAFF_TRANSACTIONS_READ',
                'MERCHANT_STAFF_STATEMENT_READ',
                'MERCHANT_STAFF_STATEMENT_EXPORT',
                'MERCHANT_STAFF_SALES_REPORT_READ',
                'MERCHANT_STAFF_SALES_REPORT_EXPORT'
              ])
                {
                  ...statusEvent,
                  'action': action,
                  'before': null,
                  'after': null,
                  'entityId': 'b',
                  'format': action.endsWith('EXPORT') ? 'csv' : 'json',
                  'periodFrom': '2026-01-01',
                  'periodTo': '2026-01-02'
                },
            ]
          };
    await t.pumpWidget(app(api));
    await t.pumpAndSettle();
    expect(find.text('عرض رصيد المحفظة'), findsOneWidget);
    expect(find.text('عرض حركات المحفظة'), findsOneWidget);
    expect(find.textContaining('الفترة: 2026-01-01 — 2026-01-02 (UTC)'),
        findsWidgets);
    expect(find.textContaining('السعر:'), findsNothing);
    expect(find.textContaining('الاستقبال قبل:'), findsNothing);
    await t.scrollUntilVisible(find.text('تجهيز تصدير تقرير المبيعات'), 200,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    expect(find.text('تجهيز تصدير تقرير المبيعات'), findsOneWidget);
    expect(find.textContaining('جُهّز CSV؛ حفظ الملف على الجهاز إجراء مستقل.'),
        findsWidgets);
  });
  testWidgets(
      'financial action filter changes query without carrying a previous cursor',
      (t) async {
    final api = ActivityApi()
      ..respond = (_) async => {'items': [], 'nextCursor': 'old'};
    await t.pumpWidget(app(api));
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('تجهيز تصدير تقرير المبيعات'), 200,
        scrollable: find.byType(Scrollable).last);
    await t.tap(find.text('تجهيز تصدير تقرير المبيعات').last);
    await t.pumpAndSettle();
    expect(api.requests.last.queryParameters['action'],
        'MERCHANT_STAFF_SALES_REPORT_EXPORT');
    expect(api.requests.last.queryParameters.containsKey('cursor'), isFalse);
    expect(api.requests.last.queryParameters['subjectId'], 'employee');
  });

  testWidgets(
      'order activity shows transition, actor and reference without product fields',
      (t) async {
    final api = ActivityApi()
      ..respond = (_) async => {
            'items': [
              {
                ...statusEvent,
                'action': 'ORDER_STATUS_CHANGED',
                'entityId': 'order-1',
                'before': {'status': 'pending'},
                'after': {'status': 'confirmed'},
              }
            ]
          };
    await t.pumpWidget(app(api));
    await t.pumpAndSettle();
    expect(find.text('تغيير حالة طلب'), findsOneWidget);
    expect(
        find.textContaining('حالة الطلب قبل: بانتظار القبول'), findsOneWidget);
    expect(find.textContaining('حالة الطلب بعد: مقبول'), findsOneWidget);
    expect(find.textContaining('المرجع: order-1'), findsOneWidget);
    expect(find.textContaining('أحمد'), findsOneWidget);
    expect(find.textContaining('السعر:'), findsNothing);
    expect(find.textContaining('الاستقبال قبل:'), findsNothing);
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('تغيير حالة طلب').last);
    await t.pumpAndSettle();
    expect(api.requests.last.queryParameters['action'], 'ORDER_STATUS_CHANGED');
    expect(api.requests.last.queryParameters.containsKey('cursor'), isFalse);
  });
  testWidgets('missing historical order state is not inferred', (t) async {
    final api = ActivityApi()
      ..respond = (_) async => {
            'items': [
              {
                ...statusEvent,
                'action': 'ORDER_STATUS_CHANGED',
                'before': null,
                'after': {'status': 'ready'},
              }
            ]
          };
    await t.pumpWidget(app(api));
    await t.pumpAndSettle();
    expect(find.textContaining('حالة الطلب قبل: غير مسجل'), findsOneWidget);
    expect(find.textContaining('حالة الطلب بعد: جاهز'), findsOneWidget);
  });

  testWidgets(
      'owner sees actor and status before/after without a product price',
      (t) async {
    final api = ActivityApi();
    await t.pumpWidget(app(api));
    await t.pumpAndSettle();
    expect(find.text('سجل نشاط الموظفين'), findsOneWidget);
    expect(find.textContaining('الاستقبال قبل: غير متصل'), findsOneWidget);
    expect(find.textContaining('الاستقبال بعد: متصل'), findsOneWidget);
    expect(find.textContaining('أحمد'), findsOneWidget);
    expect(find.textContaining('السعر:'), findsNothing);
    expect(api.requests.single.queryParameters['subjectId'], 'employee');
  });
  testWidgets('missing historical status stays unknown rather than offline',
      (t) async {
    final api = ActivityApi()
      ..respond = (_) async => {
            'items': [
              {...statusEvent, 'before': null}
            ]
          };
    await t.pumpWidget(app(api));
    await t.pumpAndSettle();
    expect(find.textContaining('الاستقبال قبل: غير مسجل'), findsOneWidget);
  });
  testWidgets('filter starts a fresh query with its action and no old cursor',
      (t) async {
    final api = ActivityApi()
      ..respond = (_) async => {'items': [], 'nextCursor': 'page'};
    await t.pumpWidget(app(api));
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('تغيير استقبال الطلبات').last);
    await t.pumpAndSettle();
    expect(
        api.requests.last.queryParameters['action'], 'BRANCH_STATUS_CHANGED');
    expect(api.requests.last.queryParameters.containsKey('cursor'), isFalse);
    expect(find.text('لا توجد عمليات مسجلة.'), findsNothing);
    expect(find.text('المزيد من العمليات'), findsOneWidget);
    await t.tap(find.text('المزيد من العمليات'));
    await t.pumpAndSettle();
    expect(api.requests.last.queryParameters['cursor'], 'page');
  });
  testWidgets('product entries retain their name, price and action title',
      (t) async {
    final api = ActivityApi()
      ..respond = (_) async => {
            'items': [
              {
                ...statusEvent,
                'action': 'MENU_PRODUCT_CREATED',
                'after': {'name': 'وجبة', 'price': 3500}
              }
            ]
          };
    await t.pumpWidget(app(api));
    await t.pumpAndSettle();
    expect(find.text('إضافة منتج'), findsOneWidget);
    expect(find.textContaining('السعر: 3500 د.ع'), findsOneWidget);
    expect(find.textContaining('الاستقبال قبل:'), findsNothing);
  });
  testWidgets('product edit displays changed values before and after',
      (t) async {
    final api = ActivityApi()
      ..respond = (_) async => {
            'items': [
              {
                ...statusEvent,
                'action': 'MENU_PRODUCT_UPDATED',
                'before': {'name': 'وجبة', 'price': 3500, 'isAvailable': true},
                'after': {'name': 'وجبة', 'price': 4200, 'isAvailable': false}
              }
            ]
          };
    await t.pumpWidget(app(api));
    await t.pumpAndSettle();
    expect(find.text('تعديل منتج'), findsOneWidget);
    expect(find.textContaining('السعر قبل: 3500؛ بعد: 4200'), findsOneWidget);
    expect(
        find.textContaining('التوفر قبل: متاح؛ بعد: غير متاح'), findsOneWidget);
    expect(find.textContaining('الاسم قبل:'), findsNothing);
  });
  testWidgets(
      'reference search resets pagination and keeps the selected employee',
      (t) async {
    final api = ActivityApi()
      ..respond = (_) async => {'items': [], 'nextCursor': 'page'};
    await t.pumpWidget(app(api));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), ' product-123 ');
    await t.tap(find.text('تطبيق البحث'));
    await t.pumpAndSettle();
    expect(api.requests.last.queryParameters['reference'], 'product-123');
    expect(api.requests.last.queryParameters['subjectId'], 'employee');
    expect(api.requests.last.queryParameters.containsKey('cursor'), isFalse);
    await t.tap(find.text('المزيد من العمليات'));
    await t.pumpAndSettle();
    expect(api.requests.last.queryParameters['cursor'], 'page');
    expect(api.requests.last.queryParameters['reference'], 'product-123');
  });
  testWidgets('invalid reference does not issue a request', (t) async {
    final api = ActivityApi();
    await t.pumpWidget(app(api));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'product other');
    await t.tap(find.text('تطبيق البحث'));
    await t.pumpAndSettle();
    expect(api.requests.length, 1);
    expect(find.text('أدخل معرف المنتج أو الفرع أو الطلب كاملًا دون مسافات.'),
        findsOneWidget);
  });
  testWidgets(
      'calendar dates are sent as inclusive UTC days and can be cleared',
      (t) async {
    final api = ActivityApi()..respond = (_) async => {'items': []};
    await t.pumpWidget(MaterialApp(
        home: StaffProductActivityScreen(
      businessId: 'b',
      service: api,
      periodPicker: (_) async => DateTimeRange(
          start: DateTime(2026, 10, 14), end: DateTime(2026, 10, 15)),
    )));
    await t.pumpAndSettle();
    await t.tap(find.text('اختيار الفترة (UTC)'));
    await t.pumpAndSettle();
    expect(api.requests.last.queryParameters['from'], '2026-10-14');
    expect(api.requests.last.queryParameters['to'], '2026-10-15');
    expect(api.requests.last.queryParameters.containsKey('cursor'), isFalse);
    await t.tap(find.text('إلغاء الفترة'));
    await t.pumpAndSettle();
    expect(api.requests.last.queryParameters.containsKey('from'), isFalse);
    expect(api.requests.last.queryParameters.containsKey('to'), isFalse);
  });
  testWidgets('a date selection from an old branch cannot filter a new scope',
      (t) async {
    final pending = Completer<DateTimeRange?>();
    final api = ActivityApi()..respond = (_) async => {'items': []};
    await t.pumpWidget(MaterialApp(
        home: StaffProductActivityScreen(
            businessId: 'b',
            service: api,
            periodPicker: (_) => pending.future)));
    await t.pumpAndSettle();
    await t.tap(find.text('اختيار الفترة (UTC)'));
    await t.pumpWidget(MaterialApp(
        home: StaffProductActivityScreen(
            businessId: 'other',
            service: api,
            periodPicker: (_) => pending.future)));
    await t.pumpAndSettle();
    pending.complete(DateTimeRange(
        start: DateTime(2026, 10, 14), end: DateTime(2026, 10, 15)));
    await t.pumpAndSettle();
    expect(api.requests.length, 2);
    expect(api.requests.last.queryParameters['businessId'], 'other');
    expect(api.requests.last.queryParameters.containsKey('from'), isFalse);
  });
  testWidgets('failed revalidation removes the previous activity', (t) async {
    final api = ActivityApi();
    await t.pumpWidget(app(api));
    await t.pumpAndSettle();
    api.respond = (_) async => throw Exception('لا تملك صلاحية القراءة');
    await t.tap(find.text('تحديث السجل'));
    await t.pumpAndSettle();
    expect(find.textContaining('أحمد'), findsNothing);
    expect(find.text('لا تملك صلاحية القراءة'), findsOneWidget);
    expect(find.text('لا توجد عمليات مسجلة.'), findsNothing);
  });
  testWidgets('a late response for another branch cannot restore its activity',
      (t) async {
    final pending = Completer<Map<String, dynamic>>();
    final api = ActivityApi()
      ..respond = (uri) => uri.queryParameters['businessId'] == 'b'
          ? pending.future
          : Future.value({'items': []});
    await t.pumpWidget(app(api));
    await t.pumpWidget(app(api, branch: 'other', subject: 'other-employee'));
    await t.pumpAndSettle();
    pending.complete({
      'items': [statusEvent]
    });
    await t.pumpAndSettle();
    expect(find.textContaining('أحمد'), findsNothing);
    expect(api.requests.last.queryParameters['businessId'], 'other');
    expect(find.text('لا توجد عمليات مسجلة.'), findsOneWidget);
  });
}
