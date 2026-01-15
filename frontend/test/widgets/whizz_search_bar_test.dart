import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/widgets/whizz_search_bar.dart';
import 'package:whizz_merchants/core/theme/whizz_colors.dart';

void main() {
  group('WhizzSearchBar Tests', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('renders with default properties', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhizzSearchBar(
              controller: controller,
            ),
          ),
        ),
      );

      // Verify search icon is displayed
      expect(find.byIcon(Icons.search), findsOneWidget);

      // Verify default hint text
      expect(find.text('Search...'), findsOneWidget);

      // Verify clear button is not shown when empty
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('displays custom hint text', (WidgetTester tester) async {
      const customHint = 'Search products...';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhizzSearchBar(
              controller: controller,
              hintText: customHint,
            ),
          ),
        ),
      );

      expect(find.text(customHint), findsOneWidget);
    });

    testWidgets('shows clear button when text is entered',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhizzSearchBar(
              controller: controller,
            ),
          ),
        ),
      );

      // Initially no clear button
      expect(find.byIcon(Icons.clear), findsNothing);

      // Enter text
      await tester.enterText(find.byType(TextField), 'test query');
      await tester.pump();

      // Clear button should appear
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clear button clears text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhizzSearchBar(
              controller: controller,
            ),
          ),
        ),
      );

      // Enter text
      await tester.enterText(find.byType(TextField), 'test query');
      await tester.pump();

      expect(controller.text, 'test query');

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      // Text should be cleared
      expect(controller.text, '');
    });

    testWidgets('onChanged callback is triggered', (WidgetTester tester) async {
      String? changedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhizzSearchBar(
              controller: controller,
              onChanged: (value) => changedValue = value,
            ),
          ),
        ),
      );

      // Enter text
      await tester.enterText(find.byType(TextField), 'search text');
      await tester.pump();

      expect(changedValue, 'search text');
    });

    testWidgets('onSubmitted callback is triggered',
        (WidgetTester tester) async {
      String? submittedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhizzSearchBar(
              controller: controller,
              onSubmitted: (value) => submittedValue = value,
            ),
          ),
        ),
      );

      // Enter text and submit
      await tester.enterText(find.byType(TextField), 'search text');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submittedValue, 'search text');
    });

    testWidgets('displays custom prefix icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhizzSearchBar(
              controller: controller,
              prefixIcon: Icons.filter_list,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.filter_list), findsOneWidget);
      expect(find.byIcon(Icons.search), findsNothing);
    });

    testWidgets('displays custom suffix icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhizzSearchBar(
              controller: controller,
              suffixIcon: const Icon(Icons.mic),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.mic), findsOneWidget);

      // Enter text - clear button should not appear because suffixIcon overrides it
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsNothing);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('disabled state prevents interaction',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhizzSearchBar(
              controller: controller,
              enabled: false,
            ),
          ),
        ),
      );

      // Try to enter text
      await tester.enterText(find.byType(TextField), 'should not work');
      await tester.pump();

      // Text should not be entered when disabled
      expect(controller.text, '');
    });

    testWidgets('applies custom border radius', (WidgetTester tester) async {
      const customRadius = BorderRadius.all(Radius.circular(100));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhizzSearchBar(
              controller: controller,
              borderRadius: customRadius,
            ),
          ),
        ),
      );

      // Widget builds without errors
      expect(find.byType(WhizzSearchBar), findsOneWidget);
    });

    testWidgets('applies custom colors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhizzSearchBar(
              controller: controller,
              backgroundColor: WhizzColors.grey100,
              focusColor: WhizzColors.secondary,
            ),
          ),
        ),
      );

      // Widget builds without errors
      expect(find.byType(WhizzSearchBar), findsOneWidget);
    });
  });

  group('WhizzSearchBarCompact Tests', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('renders compact version', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhizzSearchBarCompact(
              controller: controller,
            ),
          ),
        ),
      );

      // Verify it uses WhizzSearchBar internally
      expect(find.byType(WhizzSearchBar), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('compact version accepts callbacks',
        (WidgetTester tester) async {
      String? changedValue;
      String? submittedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WhizzSearchBarCompact(
              controller: controller,
              onChanged: (value) => changedValue = value,
              onSubmitted: (value) => submittedValue = value,
            ),
          ),
        ),
      );

      // Enter and submit text
      await tester.enterText(find.byType(TextField), 'compact search');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(changedValue, 'compact search');
      expect(submittedValue, 'compact search');
    });
  });

  group('WhizzSearchBar Integration Tests', () {
    testWidgets('focus state changes are handled', (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                WhizzSearchBar(controller: controller),
                const TextField(), // Second field to test focus change
              ],
            ),
          ),
        ),
      );

      // Tap the search bar to focus
      await tester.tap(find.byType(WhizzSearchBar));
      await tester.pump();

      // Widget should handle focus
      expect(find.byType(WhizzSearchBar), findsOneWidget);

      // Tap the other text field to lose focus
      await tester.tap(find.byType(TextField).last);
      await tester.pump();

      // Widget should handle focus loss
      expect(find.byType(WhizzSearchBar), findsOneWidget);

      controller.dispose();
    });

    testWidgets('multiple search bars can coexist',
        (WidgetTester tester) async {
      final controller1 = TextEditingController();
      final controller2 = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                WhizzSearchBar(
                  controller: controller1,
                  hintText: 'Search 1',
                ),
                WhizzSearchBar(
                  controller: controller2,
                  hintText: 'Search 2',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(WhizzSearchBar), findsNWidgets(2));
      expect(find.text('Search 1'), findsOneWidget);
      expect(find.text('Search 2'), findsOneWidget);

      controller1.dispose();
      controller2.dispose();
    });
  });
}
