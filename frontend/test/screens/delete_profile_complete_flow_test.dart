import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/screens/delete_account_screen.dart';
import 'package:whizz_merchants/services/account_deletion_service.dart';

void main() {
  final token = 'header.${base64Url.encode(utf8.encode(jsonEncode({
            'sub': 'member',
            'exp': 4102444800
          }))).replaceAll('=', '')}.signature';
  setUp(() => FlutterSecureStorage.setMockInitialValues(
      {'secure_access_token': token}));
  Future<void> mount(
      WidgetTester tester, AccountDeletionService service) async {
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: DeleteAccountScreen(
                scope: service.scope,
                businessId: service.businessId,
                service: service))));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('Consent and telephone code precede the durable deletion request',
      (tester) async {
    final requests = <Map<String, dynamic>>[];
    final service = AccountDeletionService(
        scope: 'BUSINESS',
        businessId: 'store',
        client: MockClient((r) async {
          if (r.method == 'GET') return http.Response('{"request":null}', 200);
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          if (r.url.path.endsWith('/send'))
            return http.Response(
                '{"challengeId":"proof","phoneHint":"****8280","resendAfter":60}',
                200);
          requests.add(body);
          return http.Response(
              '{"requestId":"request","status":"PENDING_SETTLEMENT","blockers":[{"code":"REFUND_REQUIRED","amount":5000}]}',
              200);
        }));
    await mount(tester, service);
    expect(
        tester
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'إرسال رمز التحقق'))
            .onPressed,
        isNull);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect(
        tester
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'إرسال رمز التحقق'))
            .onPressed,
        isNotNull);
    await tap(tester, 'إرسال رمز التحقق');
    expect(requests, isEmpty);
    await tester.scrollUntilVisible(find.byType(TextField), 200, scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
    expect(find.byType(TextField), findsOneWidget);
    expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText, isFalse);
    await tester.enterText(find.byType(TextField), '123456');
    await tap(tester, 'تأكيد طلب الحذف');
    expect(
        requests.single['scope'], {'kind': 'BUSINESS', 'businessId': 'store'});
    expect(requests.single['challengeId'], 'proof');
    expect(requests.single['code'], '123456');
    expect(find.textContaining('بانتظار تسوية'), findsOneWidget);
    expect(find.textContaining('5000'), findsOneWidget);
    expect(find.text('اكتمل إغلاق وحذف المطعم'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'Unknown status after outage cannot enable sending a deletion code',
      (tester) async {
    await mount(
        tester,
        AccountDeletionService(
            scope: 'ACCOUNT',
            client: MockClient(
                (_) async => http.Response('{"message":"offline"}', 503))));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(
        tester
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'إرسال رمز التحقق'))
            .onPressed,
        isNull);
    expect(find.text('offline'), findsOneWidget);
    expect(find.text('اكتمل حذف الحساب'), findsNothing);
  });
  testWidgets('Completed membership removal keeps the personal session',
      (tester) async {
    await mount(
        tester,
        AccountDeletionService(
            scope: 'MEMBERSHIP',
            businessId: 'store',
            client: MockClient((_) async => http.Response(
                '{"request":{"requestId":"request","status":"COMPLETED"}}',
                200))));
    expect(find.text('اكتملت مغادرة المطعم وإزالة الصلاحيات'), findsOneWidget);
    expect(await const FlutterSecureStorage().read(key: 'secure_access_token'),
        token);
  });
}
