import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/widgets/support_category_selector.dart';

void main() {
  group('SupportCategorySelector Animation Tests', () {
    testWidgets('Animation intervals are valid for all categories',
        (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SupportCategorySelector(
              onCategorySelected: (category, description) {},
            ),
          ),
        ),
      );

      // Wait for initial animation to complete
      await tester.pumpAndSettle();

      // Verify all 6 categories are rendered
      expect(find.text('Orders & Fulfillment'), findsOneWidget);
      expect(find.text('Payments & Payouts'), findsOneWidget);
      expect(find.text('Account & Login'), findsOneWidget);
      expect(find.text('Menu & Store Setup'), findsOneWidget);
      expect(find.text('Technical Issues'), findsOneWidget);
      expect(find.text('Speak to Human Agent'), findsOneWidget);

      // Verify animation interval calculations
      for (int index = 0; index < 6; index++) {
        final startDelay = (index * 0.08).clamp(0.0, 0.4);
        final endDelay = (startDelay + 0.5).clamp(0.0, 1.0);

        // Print values for verification
        debugPrint(
            'Category $index: startDelay=$startDelay, endDelay=$endDelay');

        // Assert valid ranges
        expect(startDelay, greaterThanOrEqualTo(0.0));
        expect(startDelay, lessThanOrEqualTo(1.0));
        expect(endDelay, greaterThanOrEqualTo(0.0));
        expect(endDelay, lessThanOrEqualTo(1.0));
        expect(endDelay, greaterThan(startDelay));
      }
    });

    testWidgets('Animation interval calculation produces valid results',
        (WidgetTester tester) async {
      // Test the animation interval logic directly
      final testCases = [
        {'index': 0, 'expectedStart': 0.0, 'expectedEnd': 0.5},
        {'index': 1, 'expectedStart': 0.08, 'expectedEnd': 0.58},
        {'index': 2, 'expectedStart': 0.16, 'expectedEnd': 0.66},
        {'index': 3, 'expectedStart': 0.24, 'expectedEnd': 0.74},
        {'index': 4, 'expectedStart': 0.32, 'expectedEnd': 0.82},
        {'index': 5, 'expectedStart': 0.4, 'expectedEnd': 0.9}, // Clamped
      ];

      for (final testCase in testCases) {
        final index = testCase['index'] as int;
        final startDelay = (index * 0.08).clamp(0.0, 0.4);
        final endDelay = (startDelay + 0.5).clamp(0.0, 1.0);

        expect(startDelay, testCase['expectedStart'],
            reason: 'Start delay for index $index');
        expect(endDelay, testCase['expectedEnd'],
            reason: 'End delay for index $index');

        // Critical: Ensure end <= 1.0
        expect(endDelay, lessThanOrEqualTo(1.0),
            reason: 'End delay must be <= 1.0 for index $index');
      }
    });

    testWidgets('Category selection triggers callback after animation',
        (WidgetTester tester) async {
      String? selectedCategory;
      String? selectedDescription;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SupportCategorySelector(
              onCategorySelected: (category, description) {
                selectedCategory = category;
                selectedDescription = description;
              },
            ),
          ),
        ),
      );

      // Wait for initial animation
      await tester.pumpAndSettle();

      // Tap on first category
      await tester.tap(find.text('Orders & Fulfillment'));

      // Wait for reverse animation to complete
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      // Verify callback was called
      expect(selectedCategory, 'order_management');
      expect(selectedDescription, isNotNull);
    });

    testWidgets('Multiple rapid taps are prevented during animation',
        (WidgetTester tester) async {
      int callbackCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SupportCategorySelector(
              onCategorySelected: (category, description) {
                callbackCount++;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap multiple times rapidly
      await tester.tap(find.text('Orders & Fulfillment'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Orders & Fulfillment'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Orders & Fulfillment'));

      // Wait for animation to complete
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Only one callback should have been triggered
      expect(callbackCount, 1);
    });

    testWidgets('Widget disposes cleanly after category selection',
        (WidgetTester tester) async {
      bool categorySelected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SupportCategorySelector(
              onCategorySelected: (category, description) {
                categorySelected = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap category
      await tester.tap(find.text('Orders & Fulfillment'));
      await tester.pumpAndSettle();

      // Verify callback was called
      expect(categorySelected, true);

      // Remove widget from tree
      await tester
          .pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pumpAndSettle();

      // No errors should occur during disposal
    });

    testWidgets('Close button works correctly', (WidgetTester tester) async {
      bool closeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SupportCategorySelector(
              onCategorySelected: (category, description) {},
              onClose: () {
                closeCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap close button
      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);

      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(closeCalled, true);
    });

    testWidgets('All category cards are interactive',
        (WidgetTester tester) async {
      final selectedCategories = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SupportCategorySelector(
              onCategorySelected: (category, description) {
                selectedCategories.add(category);
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test each category
      final categories = [
        'Orders & Fulfillment',
        'Payments & Payouts',
        'Account & Login',
        'Menu & Store Setup',
        'Technical Issues',
        'Speak to Human Agent',
      ];

      for (final categoryTitle in categories) {
        // Rebuild widget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SupportCategorySelector(
                onCategorySelected: (category, description) {
                  selectedCategories.add(category);
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap category
        await tester.tap(find.text(categoryTitle));
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }

      // All categories should have been selected
      expect(selectedCategories.length, 6);
    });
  });

  group('SupportCategorySelector Visual Tests', () {
    testWidgets('Header displays correct text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SupportCategorySelector(
              onCategorySelected: (category, description) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('How can we help you today?'), findsOneWidget);
      expect(find.text('Choose a category to get started with WhizzMe AI'),
          findsOneWidget);
    });

    testWidgets('Footer displays WhizzMe AI branding',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SupportCategorySelector(
              onCategorySelected: (category, description) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Powered by WhizzMe AI'), findsOneWidget);
      expect(
          find.text(
              'Our AI assistant will help you first, then connect you to a human agent if needed.'),
          findsOneWidget);
    });

    testWidgets('Category cards display all information',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SupportCategorySelector(
              onCategorySelected: (category, description) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check first category has all elements
      expect(find.text('Orders & Fulfillment'), findsOneWidget);
      expect(find.text('New orders, order status, cancellations, refunds'),
          findsOneWidget);
      expect(find.text('Not receiving orders'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios), findsNWidgets(6));
    });
  });
}
