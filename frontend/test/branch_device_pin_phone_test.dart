import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/screens/branch_device_pin_setup_screen.dart';
import 'package:whizz_merchants/services/person_onboarding_service.dart';
import 'package:whizz_merchants/services/app_auth_service.dart';

class PinApi extends PersonOnboardingService {
  String? sent;
  bool fail = false;
  @override
  Future<bool> startPhoneSignIn(String phone) async {
    sent = phone;
    if (fail) throw PhoneAuthException(PhoneAuthError.notRegistered);
    return true;
  }
}

void main() {
  for (final input in [
    '7831367435',
    '07831367435',
    '+9647831367435',
    '٧٨٣١٣٦٧٤٣٥'
  ]) {
    testWidgets('PIN normalizes $input before authentication', (tester) async {
      final api = PinApi();
      await tester.pumpWidget(MaterialApp(
          home: BranchDevicePinSetupScreen(
              businessId: 'b', deviceToken: 'test', service: api)));
      await tester.enterText(find.byType(TextField), input);
      await tester.ensureVisible(find.text('إرسال رمز التحقق'));
      await tester.tap(find.text('إرسال رمز التحقق'));
      await tester.pumpAndSettle();
      expect(api.sent, '+9647831367435');
      expect(find.text('رمز التحقق المرسل لهاتفك'), findsOneWidget);
    });
  }
  testWidgets('invalid phone never starts authentication and errors are Arabic',
      (tester) async {
    final api = PinApi();
    await tester.pumpWidget(MaterialApp(
        home: BranchDevicePinSetupScreen(
            businessId: 'b', deviceToken: 'test', service: api)));
    await tester.enterText(find.byType(TextField), '123');
    await tester.ensureVisible(find.text('إرسال رمز التحقق'));
    await tester.tap(find.text('إرسال رمز التحقق'));
    await tester.pumpAndSettle();
    expect(api.sent, isNull);
    expect(find.textContaining('أدخل رقم هاتف عراقيًا صحيحًا'), findsOneWidget);
    api.fail = true;
    await tester.enterText(find.byType(TextField), '7831367435');
    await tester.tap(find.text('إرسال رمز التحقق'));
    await tester.pumpAndSettle();
    expect(find.textContaining('لم يُعثر على حساب بهذا الرقم'), findsOneWidget);
    expect(find.textContaining('PhoneAuthException'), findsNothing);
  });
}
