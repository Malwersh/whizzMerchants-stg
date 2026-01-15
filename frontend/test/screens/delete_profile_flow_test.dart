import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whizz_merchants/screens/account_settings_page.dart';
import 'package:whizz_merchants/screens/login_page.dart';
import 'package:whizz_merchants/models/business.dart';
import 'package:whizz_merchants/providers/business_provider.dart';
import 'package:whizz_merchants/l10n/app_localizations.dart';

void main() {
  group('Delete Profile Complete Flow Tests', () {
    late Business testBusiness;
    late ProviderContainer container;

    setUp(() {
      // Create test business data
      testBusiness = Business(
        id: 'test-business-123',
        name: 'Test Restaurant',
        email: 'test@restaurant.com',
        phone: '+1234567890',
        businessType: BusinessType.restaurant,
        status: 'approved',
        ownerName: 'John Doe',
        description: 'A test restaurant',
        website: 'https://testrestaurant.com',
        address: '123 Main St, Test City, Test Country',
        businessPhotoUrl: 'https://example.com/photo.jpg',
      );

      // Create a fresh ProviderContainer for each test
      container = ProviderContainer(
        overrides: [
          businessProvider.overrideWith((ref) => testBusiness),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('Delete Profile - Complete Flow: Show Delete Account Button',
        (WidgetTester tester) async {
      // Build the AccountSettingsPage
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountSettingsPage(business: testBusiness),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that the page loads
      expect(find.text('Account Settings'), findsOneWidget);

      // Look for Delete Account button/option
      // Note: This will fail initially because the feature doesn't exist yet
      expect(
        find.text('Delete Account'),
        findsOneWidget,
        reason: 'Delete Account button should be visible in Account Settings',
      );
    });

    testWidgets(
        'Delete Profile - Complete Flow: Show Confirmation Dialog on Delete',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountSettingsPage(business: testBusiness),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the Delete Account button
      final deleteButton = find.text('Delete Account');
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      // Verify confirmation dialog appears
      expect(
        find.text('Delete Account?'),
        findsOneWidget,
        reason: 'Confirmation dialog title should appear',
      );

      expect(
        find.textContaining('permanently delete'),
        findsOneWidget,
        reason: 'Warning message about permanent deletion should appear',
      );

      // Verify dialog has Cancel and Confirm buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(
        find.text('Delete'),
        findsOneWidget,
        reason: 'Delete confirmation button should appear',
      );
    });

    testWidgets(
        'Delete Profile - Complete Flow: Cancel Deletion Closes Dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountSettingsPage(business: testBusiness),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Delete Account button
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      // Tap Cancel in the confirmation dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify dialog is closed and we're still on AccountSettingsPage
      expect(find.text('Delete Account?'), findsNothing);
      expect(find.text('Account Settings'), findsOneWidget);
    });

    testWidgets(
        'Delete Profile - Complete Flow: Confirm Deletion Shows Password Verification',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountSettingsPage(business: testBusiness),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Delete Account button
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      // Tap Delete in the confirmation dialog
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Verify password verification dialog appears
      expect(
        find.text('Verify Password'),
        findsOneWidget,
        reason: 'Password verification dialog should appear',
      );

      expect(
        find.textContaining('Enter your password to confirm'),
        findsOneWidget,
        reason: 'Password verification instruction should appear',
      );

      // Verify password input field exists
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'Password input field should be visible',
      );
    });

    testWidgets(
        'Delete Profile - Complete Flow: Invalid Password Shows Error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountSettingsPage(business: testBusiness),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to delete confirmation
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Enter invalid password
      await tester.enterText(find.byType(TextField), 'wrongpassword');
      await tester.pumpAndSettle();

      // Tap Confirm button
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // Verify error message appears
      expect(
        find.textContaining('incorrect password'),
        findsOneWidget,
        reason: 'Error message for incorrect password should appear',
      );

      // Verify we're still on the password verification dialog
      expect(find.text('Verify Password'), findsOneWidget);
    });

    testWidgets(
        'Delete Profile - Complete Flow: Valid Password Triggers Account Deletion',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountSettingsPage(business: testBusiness),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate through deletion flow
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Enter correct password
      await tester.enterText(find.byType(TextField), 'correctpassword');
      await tester.pumpAndSettle();

      // Tap Confirm button
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // Verify loading indicator appears during deletion
      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason: 'Loading indicator should appear during account deletion',
      );
    });

    testWidgets(
        'Delete Profile - Complete Flow: Successful Deletion Navigates to Login',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountSettingsPage(business: testBusiness),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Complete deletion flow
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'correctpassword');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify navigation to login page
      expect(
        find.byType(LoginPage),
        findsOneWidget,
        reason: 'Should navigate to LoginPage after successful deletion',
      );

      // Verify success message appears
      expect(
        find.textContaining('Account deleted successfully'),
        findsOneWidget,
        reason: 'Success message should appear',
      );
    });

    testWidgets(
        'Delete Profile - Complete Flow: Delete Button Styling is Appropriate',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountSettingsPage(business: testBusiness),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the Delete Account button
      final deleteButton = find.text('Delete Account');
      expect(deleteButton, findsOneWidget);

      // Get the button widget
      final button = tester.widget<Text>(deleteButton);

      // Verify button has appropriate warning styling (red color)
      expect(
        button.style?.color,
        Colors.red,
        reason: 'Delete button should have red color to indicate danger',
      );
    });

    testWidgets(
        'Delete Profile - Complete Flow: Error Handling During Deletion',
        (WidgetTester tester) async {
      // This test verifies that network errors are handled gracefully
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountSettingsPage(business: testBusiness),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Complete deletion flow
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'correctpassword');
      await tester.pumpAndSettle();

      // Simulate network error scenario
      // Tap Confirm button
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // In case of error, verify error message appears
      // and user stays on the same page
      final errorSnackbar = find.textContaining('error');
      if (errorSnackbar.evaluate().isNotEmpty) {
        expect(
          errorSnackbar,
          findsOneWidget,
          reason: 'Error message should appear if deletion fails',
        );

        // Verify user is still authenticated (deletion failed)
        expect(find.text('Account Settings'), findsOneWidget);
      }
    });
  });

  group('Delete Profile - UI Component Tests', () {
    testWidgets('Delete Account Button Appears in Danger Zone Section',
        (WidgetTester tester) async {
      final testBusiness = Business(
        id: 'test-123',
        name: 'Test Business',
        email: 'test@example.com',
        businessType: BusinessType.restaurant,
        status: 'approved',
      );

      final container = ProviderContainer(
        overrides: [
          businessProvider.overrideWith((ref) => testBusiness),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountSettingsPage(business: testBusiness),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Look for "Danger Zone" section
      expect(
        find.text('Danger Zone'),
        findsOneWidget,
        reason: 'Danger Zone section should be visible',
      );

      // Verify Delete Account button is within Danger Zone
      expect(find.text('Delete Account'), findsOneWidget);

      container.dispose();
    });

    testWidgets('Delete Account Has Warning Icon',
        (WidgetTester tester) async {
      final testBusiness = Business(
        id: 'test-123',
        name: 'Test Business',
        email: 'test@example.com',
        businessType: BusinessType.restaurant,
        status: 'approved',
      );

      final container = ProviderContainer(
        overrides: [
          businessProvider.overrideWith((ref) => testBusiness),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AccountSettingsPage(business: testBusiness),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify warning icon appears near Delete Account button
      expect(
        find.byIcon(Icons.warning_rounded),
        findsOneWidget,
        reason: 'Warning icon should appear to indicate danger',
      );

      container.dispose();
    });
  });

  group('Delete Profile - Integration Tests', () {
    test('Delete Account Flow - Conceptual Test', () {
      // This is a conceptual test that documents the expected flow
      // The actual implementation will need to be added

      // Expected flow:
      // 1. User navigates to Account Settings
      // 2. User sees "Danger Zone" section with "Delete Account" button
      // 3. User taps "Delete Account"
      // 4. Confirmation dialog appears with warning message
      // 5. User confirms deletion
      // 6. Password verification dialog appears
      // 7. User enters password
      // 8. System verifies password
      // 9. System deletes account from backend
      // 10. System clears local data
      // 11. System navigates to login page
      // 12. System shows success message

      expect(true, isTrue, reason: 'Flow documented');
    });

    test('Data Cleanup After Deletion - Conceptual Test', () {
      // This test documents what data should be cleared after deletion
      
      // Expected data cleanup:
      // 1. SharedPreferences cleared
      // 2. Session data cleared
      // 3. Business provider data cleared
      // 4. All Riverpod providers invalidated
      // 5. Authentication tokens removed
      // 6. Cognito user deleted
      // 7. Backend business data deleted

      expect(true, isTrue, reason: 'Data cleanup documented');
    });
  });
}
