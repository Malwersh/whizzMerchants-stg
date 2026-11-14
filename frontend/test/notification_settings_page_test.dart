import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:whizz_merchants/screens/notification_settings_page.dart';

void main() {
  testWidgets('denied permission opens OS settings without claiming enabled', (tester) async {
    var opened = 0, registered = 0;
    await tester.pumpWidget(MaterialApp(home: NotificationSettingsPage(
      readPermission: () async => AuthorizationStatus.denied,
      openSettings: () async { opened++; return true; },
      registerDevice: () async { registered++; },
      registrationStatus: ValueNotifier('لم يُسجّل هذا الجهاز بعد.'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('الإشعارات غير مسموحة على هذا الجهاز'), findsOneWidget);
    expect(find.text('السماح بالإشعارات'), findsNothing);
    await tester.tap(find.text('فتح إعدادات الهاتف'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(registered, 0);
  });
  testWidgets('undetermined permission requests consent then registers', (tester) async {
    var requested = 0, registered = 0;
    await tester.pumpWidget(MaterialApp(home: NotificationSettingsPage(
      readPermission: () async => AuthorizationStatus.notDetermined,
      requestPermission: () async { requested++; return AuthorizationStatus.authorized; },
      registerDevice: () async { registered++; },
      registrationStatus: ValueNotifier('جارٍ التسجيل'),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('السماح بالإشعارات'));
    await tester.pumpAndSettle();
    expect(requested, 1);
    expect(registered, 1);
    expect(find.text('الإشعارات مسموحة على هذا الجهاز'), findsOneWidget);
  });
  testWidgets('resume rereads OS permission and registers newly authorized device', (tester) async {
    var permission = AuthorizationStatus.denied, registered = 0;
    await tester.pumpWidget(MaterialApp(home: NotificationSettingsPage(
      readPermission: () async => permission,
      registerDevice: () async { registered++; },
      registrationStatus: ValueNotifier('لم يُسجّل هذا الجهاز بعد.'),
    )));
    await tester.pumpAndSettle();
    permission = AuthorizationStatus.authorized;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(registered, 1);
    expect(find.text('الإشعارات مسموحة على هذا الجهاز'), findsOneWidget);
  });
}
