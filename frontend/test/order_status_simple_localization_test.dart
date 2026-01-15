import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:whizz_merchants/l10n/app_localizations.dart';
import 'package:whizz_merchants/models/order.dart';

void main() {
  group('Order Status Localization Tests', () {
    testWidgets('Verify all order status translations exist in English',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [
            Locale('en'),
            Locale('ar'),
          ],
          home: Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context)!;

              // Test all order status translations
              final statusTranslations = {
                OrderStatus.pending: loc.orderStatusPending,
                OrderStatus.confirmed: loc.orderStatusConfirmed,
                OrderStatus.preparing: loc.orderStatusPreparing,
                OrderStatus.ready: loc.orderStatusReady,
                OrderStatus.completed: loc.orderStatusCompleted,
                OrderStatus.cancelled: loc.orderStatusCancelled,
                OrderStatus.expired: loc.orderStatusExpired,
                OrderStatus.onTheWay: loc.orderStatusOnTheWay,
                OrderStatus.delivered: loc.orderStatusDelivered,
                OrderStatus.returned: loc.orderStatusReturned,
              };

              return Scaffold(
                body: Column(
                  children: statusTranslations.entries
                      .map((e) => Text('${e.key.name}: ${e.value}',
                          key: Key(e.key.name)))
                      .toList(),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify English translations exist
      expect(find.text('pending: Pending'), findsOneWidget);
      expect(find.text('confirmed: Confirmed'), findsOneWidget);
      expect(find.text('preparing: Preparing'), findsOneWidget);
      expect(find.text('ready: Ready'), findsOneWidget);
      expect(find.text('completed: Completed'), findsOneWidget);
      expect(find.text('cancelled: Cancelled'), findsOneWidget);
      expect(find.text('expired: Expired'), findsOneWidget);
      expect(find.text('onTheWay: On the Way'), findsOneWidget);
      expect(find.text('delivered: Delivered'), findsOneWidget);
      expect(find.text('returned: Returned'), findsOneWidget);
    });

    testWidgets('Verify all order status translations exist in Arabic',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [
            Locale('en'),
            Locale('ar'),
          ],
          home: Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context)!;

              // Test all order status translations
              final statusTranslations = {
                OrderStatus.pending: loc.orderStatusPending,
                OrderStatus.confirmed: loc.orderStatusConfirmed,
                OrderStatus.preparing: loc.orderStatusPreparing,
                OrderStatus.ready: loc.orderStatusReady,
                OrderStatus.completed: loc.orderStatusCompleted,
                OrderStatus.cancelled: loc.orderStatusCancelled,
                OrderStatus.expired: loc.orderStatusExpired,
                OrderStatus.onTheWay: loc.orderStatusOnTheWay,
                OrderStatus.delivered: loc.orderStatusDelivered,
                OrderStatus.returned: loc.orderStatusReturned,
              };

              return Scaffold(
                body: Column(
                  children: statusTranslations.entries
                      .map((e) => Text('${e.key.name}: ${e.value}',
                          key: Key(e.key.name)))
                      .toList(),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Arabic translations exist
      expect(find.text('pending: قيد الانتظار'), findsOneWidget);
      expect(find.text('confirmed: مؤكد'), findsOneWidget);
      expect(find.text('preparing: قيد التحضير'), findsOneWidget);
      expect(find.text('ready: جاهز'), findsOneWidget);
      expect(find.text('completed: مكتمل'), findsOneWidget);
      expect(find.text('cancelled: ملغي'), findsOneWidget);
      expect(find.text('expired: منتهي الصلاحية'), findsOneWidget);
      expect(find.text('onTheWay: في الطريق'), findsOneWidget);
      expect(find.text('delivered: تم التوصيل'), findsOneWidget);
      expect(find.text('returned: مُرجع'), findsOneWidget);
    });
  });
}
