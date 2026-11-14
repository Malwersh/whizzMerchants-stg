import 'application_legal_344_test.dart' show FakeLegal;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/screens/auth/person_registration_screen.dart';
import 'package:whizz_merchants/services/person_onboarding_service.dart';

class FixtureApi extends PersonOnboardingService {
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    calls.add('$path:${body == null ? 'GET' : 'POST'}');
    if (path == 'person-registration' && body == null)
      return {
        'acknowledgementVersion': 'fixture',
        'acknowledgementText': 'أوافق على إنشاء حساب شخصي'
      };
    return {'success': true};
  }

  @override
  Future<bool> startPhoneSignIn(String phone) async {
    calls.add('SEND_OTP');
    return true;
  }

  @override
  Future<bool> verifyPhoneCode(String code) async {
    calls.add('VERIFY_OTP');
    return false;
  }
}

void main() {
  testWidgets(
      'personal details lead to OTP; wrong OTP never creates profile or opens activity entry',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FixtureApi();
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: PersonRegistrationScreen(
                service: api, legalService: FakeLegal()))));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Test');
    await tester.enterText(fields.at(1), 'Owner');
    await tester.enterText(fields.at(2), '07800000000');
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.byType(CheckboxListTile).at(i));
      await tester.tap(find.byType(CheckboxListTile).at(i));
    }
    await tester.ensureVisible(find.text('إرسال رمز التحقق'));
    await tester.pump();
    await tester.tap(find.text('إرسال رمز التحقق'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('تأكيد رقم الهاتف'), findsOneWidget);
    expect(find.text('اسم النشاط'), findsNothing);
    expect(api.calls, contains('SEND_OTP'));
    expect(api.calls, isNot(contains('person-profile:POST')));
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('تأكيد الهاتف ومتابعة'));
    await tester.pump();
    expect(api.calls, contains('VERIFY_OTP'));
    expect(api.calls, isNot(contains('person-profile:POST')));
    expect(find.textContaining('رمز غير صحيح'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
