import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/screens/splash_screen.dart';

void main() {
  testWidgets('Splash screen displays correctly', (WidgetTester tester) async {
    // Build splash screen
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          nextScreen: const Scaffold(
            body: Center(child: Text('Next Screen')),
          ),
        ),
      ),
    );

    // Verify splash screen renders
    expect(find.text('WHIZZ'), findsOneWidget);
    expect(find.text('MERCHANTS'), findsOneWidget);
    expect(find.text('Manage Your Business, Effortlessly'), findsOneWidget);
    expect(find.text('Powered by Whizz Ecosystem'), findsOneWidget);
    expect(find.text('W'), findsOneWidget); // Logo text

    // Verify loading indicator exists
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Splash screen animations initialize',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          nextScreen: const Scaffold(
            body: Center(child: Text('Next Screen')),
          ),
          duration: const Duration(milliseconds: 100),
        ),
      ),
    );

    // Initial state
    expect(find.text('WHIZZ'), findsOneWidget);

    // Let animations start
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('WHIZZ'), findsOneWidget);
  });
}
