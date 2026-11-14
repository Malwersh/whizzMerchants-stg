import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/person_profile_screen.dart';
import '../lib/services/person_onboarding_service.dart';

class FakeProfileApi extends PersonOnboardingService {
  final requests = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    if (body == null)
      return {
        'profile': {
          'name': 'الاسم القديم',
          'email': '',
          'phoneNumber': '+9647800000000',
          'version': 3
        }
      };
    requests.add(body);
    if (body['action'] == 'update_details')
      return {
        'profile': {
          'name': body['name'],
          'email': body['email'],
          'phoneNumber': '+9647800000000',
          'version': 4
        }
      };
    if (body['action'] == 'start_phone_change')
      return {
        'challenge': {
          'requestId': body['requestId'],
          'stage': body['scope'] == 'BRANCH' ? 'NEW_PHONE' : 'OLD_PHONE',
          'maskedPhone': '*******0000'
        }
      };
    if (requests.where((r) => r['action'] == 'verify_phone_change').length == 1)
      return {
        'challenge': {
          'requestId': body['requestId'],
          'stage': 'NEW_PHONE',
          'maskedPhone': '*******1111'
        }
      };
    return {
      'success': true,
      'profile': {
        'name': 'الاسم القديم',
        'email': '',
        'phoneNumber': '+9647811111111',
        'version': 4
      }
    };
  }
}

void main() {
  testWidgets(
      'personal details save uses loaded version and does not submit owner or branch fields',
      (t) async {
    final api = FakeProfileApi();
    await t.pumpWidget(MaterialApp(home: PersonProfileScreen(service: api)));
    await t.pumpAndSettle();
    await t.enterText(
        find.widgetWithText(TextField, 'الاسم الشخصي'), 'محمد علي');
    await t.tap(find.text('حفظ بياناتي'));
    await t.pumpAndSettle();
    expect(api.requests.single['baseVersion'], 3);
    expect(api.requests.single['name'], 'محمد علي');
    expect(api.requests.single.containsKey('businessId'), false);
    expect(find.text('حُفظت بياناتك الشخصية.'), findsOneWidget);
  });
  testWidgets(
      'personal phone UI progresses from old number to new number before success',
      (t) async {
    final api = FakeProfileApi();
    await t.pumpWidget(MaterialApp(home: PersonProfileScreen(service: api)));
    await t.pumpAndSettle();
    await t.enterText(
        find.widgetWithText(TextField, 'الرقم الجديد'), '07811111111');
    await t.ensureVisible(find.text('بدء التحقق'));
    await t.tap(find.text('بدء التحقق'));
    await t.pumpAndSettle();
    expect(find.text('أدخل الرمز المرسل إلى رقمك الحالي'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'رمز التحقق'), '123456');
    await t.tap(find.text('تأكيد ومتابعة'));
    await t.pumpAndSettle();
    expect(find.text('أدخل الرمز المرسل إلى الرقم الجديد'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'رمز التحقق'), '654321');
    await t.tap(find.text('تأكيد ومتابعة'));
    await t.pumpAndSettle();
    expect(find.textContaining('حُفظ هاتف الدخول الجديد'), findsOneWidget);
    expect(api.requests.first['scope'], 'PERSONAL');
  });
  testWidgets('branch phone editor never offers personal name edit', (t) async {
    final api = FakeProfileApi();
    await t.pumpWidget(MaterialApp(
        home: PersonProfileScreen(service: api, businessId: 'branch')));
    await t.pumpAndSettle();
    expect(find.text('حفظ بياناتي'), findsNothing);
    await t.enterText(
        find.widgetWithText(TextField, 'الرقم الجديد'), '07811111111');
    await t.tap(find.text('بدء التحقق'));
    await t.pumpAndSettle();
    expect(api.requests.single['businessId'], 'branch');
    expect(api.requests.single['scope'], 'BRANCH');
    expect(find.text('أدخل الرمز المرسل إلى الرقم الجديد'), findsOneWidget);
  });
}
