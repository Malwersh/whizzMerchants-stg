import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whizz_merchants/core/design_system/design_system.dart';
import 'package:whizz_merchants/providers/business_provider.dart';
import 'package:whizz_merchants/screens/merchant_businesses_screen.dart';
import 'package:whizz_merchants/screens/merchant_wallet_accounts_screen.dart';

const branchName = 'مطعم الاختبار — الفرع الرئيسي';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final path = Platform.environment['MERCHANT_PREVIEW_FONT'];
    if (path != null) {
      final bytes = ByteData.sublistView(await File(path).readAsBytes());
      for (final family in ['Roboto', 'Ahem']) {
        await (FontLoader(family)..addFont(Future.value(bytes))).load();
      }
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    }
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final token = 'e30.${base64Url.encode(utf8.encode(jsonEncode({
          'sub': 'fixture',
          'token_use': 'access',
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600
        })))}.s';
    FlutterSecureStorage.setMockInitialValues(
        {'secure_id_token': token, 'secure_access_token': token});
  });

  Future<void> show(WidgetTester t, Widget screen,
      {required bool dark,
      double width = 390,
      double scale = 1,
      Future<Map<String, dynamic>> Function()? wallets}) async {
    t.view.physicalSize = Size(width, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ProviderScope(
        overrides: [
          businessListLoaderProvider.overrideWithValue(() async => [
                {
                  'businessId': 'fixture',
                  'businessName': branchName,
                  'status': 'approved'
                }
              ]),
          merchantDraftsLoaderProvider.overrideWithValue(() async => []),
          merchantWalletAccountsLoaderProvider.overrideWithValue(wallets ??
              () async => {
                    'accounts': [
                      {
                        'businessId': 'fixture',
                        'name': branchName,
                        'isOwner': true
                      }
                    ]
                  }),
        ],
        child: MaterialApp(
            theme: DesignSystem.lightTheme,
            darkTheme: DesignSystem.darkTheme,
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            builder: (_, child) => MediaQuery(
                data: MediaQueryData(
                    size: Size(width, 1000),
                    textScaler: TextScaler.linear(scale)),
                child: child!),
            home: RepaintBoundary(
                key: const ValueKey('workspace-preview'), child: screen))));
    await t.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    for (final screen in ['branches', 'wallets']) {
      testWidgets(
          '$screen readable with ${dark ? "dark" : "light"} system theme',
          (t) async {
        await show(
            t,
            screen == 'branches'
                ? const MerchantBusinessesScreen()
                : const MerchantWalletAccountsScreen(),
            dark: dark);
        expect(find.text(branchName), findsOneWidget);
        final theme = Theme.of(t.element(find.text(branchName)));
        expect(theme.brightness, Brightness.light);
        expect(theme.cardTheme.color, Colors.white);
        expect(t.takeException(), isNull);
        final semantics = t.ensureSemantics();
        await expectLater(t, meetsGuideline(textContrastGuideline));
        semantics.dispose();
        if (dark && Platform.environment['MERCHANT_WRITE_PREVIEWS'] == '1') {
          await expectLater(
              find.byKey(const ValueKey('workspace-preview')),
              matchesGoldenFile(Uri.file(
                  '/Users/ghaythallaheebi/wiz2026/artifacts/merchant-ux-session-20261105/$screen-preview.png')));
        }
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      });
    }
  }

  for (final screen in ['branches', 'wallets']) {
    testWidgets('$screen supports narrow RTL layout and enlarged text',
        (t) async {
      await show(
          t,
          screen == 'branches'
              ? const MerchantBusinessesScreen()
              : const MerchantWalletAccountsScreen(),
          dark: true,
          width: 320,
          scale: 1.6);
      expect(find.text(branchName), findsOneWidget);
      expect(t.takeException(), isNull);
      expect(Directionality.of(t.element(find.text(branchName))),
          TextDirection.rtl);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });
  }

  testWidgets('wallet refresh clears a previous loading error', (t) async {
    var calls = 0;
    await show(t, const MerchantWalletAccountsScreen(), dark: true,
        wallets: () async {
      if (++calls == 1) throw StateError('offline');
      return {
        'accounts': [
          {'businessId': 'fixture', 'name': branchName, 'isOwner': true}
        ]
      };
    });
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    await t.tap(find.text('إعادة المحاولة'));
    await t.pumpAndSettle();
    expect(find.text(branchName), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsNothing);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
}
