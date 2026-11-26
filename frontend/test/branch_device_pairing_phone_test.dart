import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whizz_merchants/screens/branch_device_setup_screen.dart';
import 'package:whizz_merchants/services/person_onboarding_service.dart';

class PairingApi extends PersonOnboardingService {
  final actions = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    if (body == null) return {'devices': []};
    actions.add(body);
    switch (body['action']) {
      case 'pairing_phone_info':
        return {'maskedPhone': '+*********1234'};
      case 'pairing_phone_start':
        return {'session': 'challenge', 'maskedPhone': '+*********1234'};
      default:
        return {'pairingCode': '87654321'};
    }
  }
}

void main() {
  testWidgets(
      'owner verifies known phone before creating pairing, without phone input',
      (tester) async {
    final api = PairingApi();
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: BranchDeviceSetupScreen(
                businessId: 'b', owner: true, service: api))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('إنشاء رمز لجهاز الفرع'));
    await tester.tap(find.text('إنشاء رمز لجهاز الفرع'));
    await tester.pumpAndSettle();
    expect(find.text('+*********1234'), findsOneWidget);
    expect(api.actions.length, 1);
    expect(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        findsNothing);
    await tester.tap(find.text('إرسال رمز التحقق'));
    await tester.pumpAndSettle();
    final otp = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));
    expect(otp, findsOneWidget);
    await tester.enterText(otp, '123456');
    await tester.tap(find.text('تحقق وإنشاء رمز الربط'));
    await tester.pumpAndSettle();
    expect(find.text('87654321'), findsOneWidget);
    expect(api.actions.last['action'], 'pairing_phone_confirm');
    expect(
        api.actions
            .any((x) => x.containsKey('phone') || x.containsKey('phoneNumber')),
        false);
  });
}
