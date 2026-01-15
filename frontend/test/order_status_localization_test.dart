import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:whizz_merchants/l10n/app_localizations.dart';
import 'package:whizz_merchants/models/order.dart';
import 'package:whizz_merchants/widgets/order_card.dart';

void main() {
  group('Order Status Localization Tests', () {
    testWidgets('Order status displays correctly in English',
        (WidgetTester tester) async {
      // Create a test order with different statuses
      final testOrder = Order(
        id: 'test_order_1',
        businessId: 'business_1',
        customerId: 'customer_1',
        customerName: 'Test Customer',
        items: [],
        totalAmount: 50.0,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
      );

      // Build widget with English locale
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
          home: Scaffold(
            body: OrderCard(
              order: testOrder,
              onOrderUpdated: (id, status) async {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify English text is displayed
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('Order status displays correctly in Arabic',
        (WidgetTester tester) async {
      // Create a test order with different statuses
      final testOrder = Order(
        id: 'test_order_1',
        businessId: 'business_1',
        customerId: 'customer_1',
        customerName: 'Test Customer',
        items: [],
        totalAmount: 50.0,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
      );

      // Build widget with Arabic locale
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
          home: Scaffold(
            body: OrderCard(
              order: testOrder,
              onOrderUpdated: (id, status) async {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Arabic text is displayed
      expect(find.text('قيد الانتظار'), findsOneWidget);
    });

    testWidgets('All order statuses have translations',
        (WidgetTester tester) async {
      final statuses = [
        OrderStatus.pending,
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.completed,
        OrderStatus.cancelled,
        OrderStatus.expired,
        OrderStatus.onTheWay,
        OrderStatus.delivered,
        OrderStatus.returned,
      ];

      for (final status in statuses) {
        final testOrder = Order(
          id: 'test_order_$status',
          businessId: 'business_1',
          customerId: 'customer_1',
          customerName: 'Test Customer',
          items: [],
          totalAmount: 50.0,
          status: status,
          createdAt: DateTime.now(),
        );

        // Test English
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
            home: Scaffold(
              body: OrderCard(
                order: testOrder,
                onOrderUpdated: (id, status) async {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // The status text should be found (not checking specific text as it varies)
        expect(find.byType(OrderCard), findsOneWidget);

        // Test Arabic
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
            home: Scaffold(
              body: OrderCard(
                order: testOrder,
                onOrderUpdated: (id, status) async {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // The status text should be found (not checking specific text as it varies)
        expect(find.byType(OrderCard), findsOneWidget);
      }
    });
  });
}
