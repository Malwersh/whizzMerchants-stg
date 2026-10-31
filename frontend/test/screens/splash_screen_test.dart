import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/screens/splash_screen.dart';

void main() {
  testWidgets('Splash displays the current image and loading indicator',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: SplashScreen(
            nextScreen: const Scaffold(body: Text('Next Screen')))));
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName,
        'assets/images/WizBussinessico.png');
    expect(find.text('Business'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
  });
  testWidgets('Splash navigates after its configured delay', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: SplashScreen(
            duration: const Duration(milliseconds: 100),
            nextScreen: const Scaffold(body: Text('Next Screen')))));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Next Screen'), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Next Screen'), findsOneWidget);
  });
}
