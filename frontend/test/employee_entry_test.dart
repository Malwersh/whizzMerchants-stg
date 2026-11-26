import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/l10n/app_localizations.dart';
import '../lib/providers/login_intent_provider.dart';
import '../lib/screens/auth/auth_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'employee entry explains identity and offers employee registration',
      (t) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            locale: Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AuthScreen())));
    expect(find.text('إنشاء حساب'), findsOneWidget);
    expect(find.text('مالك النشاط'), findsOneWidget);
    await t.tap(find.text('موظف'));
    await t.pumpAndSettle();
    expect(container.read(loginIntentProvider), LoginIntent.employee);
    expect(find.textContaining('لن تحتاج إلى إنشاء نشاط'), findsOneWidget);
    expect(find.text('أول مرة؟ إنشاء حساب موظف'), findsWidgets);
    expect(t.takeException(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('merchant_login_intent'), 'employee');
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'new business registration stays available without choosing a login role',
      (t) async {
    await t.pumpWidget(const ProviderScope(
        child: MaterialApp(
            locale: Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AuthScreen())));
    await t.tap(find.text('إنشاء حساب'));
    await t.pumpAndSettle();
    expect(find.text('إنشاء حساب وتسجيل نشاط جديد'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  test('cold start remembers navigation preference without a membership grant',
      () async {
    SharedPreferences.setMockInitialValues(
        {'merchant_login_intent': 'employee'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(savedLoginIntentProvider.future),
        LoginIntent.employee);
    expect(container.read(loginIntentProvider), isNull);
  });
}
