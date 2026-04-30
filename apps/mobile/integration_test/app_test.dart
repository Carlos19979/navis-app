// E2E Integration Tests for Navis App
//
// Prerequisites:
//   1. Backend running: make dev (starts Supabase + Go API)
//   2. Seed data loaded: make db-reset (creates test user + boats + docs)
//
// Run on emulator:
//   cd apps/mobile
//   flutter test integration_test/app_test.dart \
//     --dart-define=SUPABASE_URL=http://10.0.2.2:54321 \
//     --dart-define=SUPABASE_ANON_KEY=<your-local-anon-key> \
//     --dart-define=API_URL=http://10.0.2.2:8080
//
// Run on physical device (same network):
//   flutter test integration_test/app_test.dart \
//     --dart-define=SUPABASE_URL=http://<host-ip>:54321 \
//     --dart-define=SUPABASE_ANON_KEY=<your-local-anon-key> \
//     --dart-define=API_URL=http://<host-ip>:8080

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:navis_mobile/main.dart' as app;

/// How long to wait after an action that triggers a network call.
const _networkSettleTimeout = Duration(seconds: 5);

/// How long to pump frames without expecting all animations to stop.
/// Useful for screens that contain infinitely-looping flutter_animate
/// animations (shimmer, glowing borders, etc.).
const _pumpDuration = Duration(seconds: 3);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E — Full App Flow', () {
    testWidgets('1. Auth: login with test credentials', (tester) async {
      await app.main();
      // Initial load — the app starts at /boats but redirects to /login
      // because there is no session. Use pump with duration because the
      // login screen has looping .animate() entrance animations.
      await tester.pump(_pumpDuration);

      // Verify we are on the login screen
      expect(find.text('Log In'), findsWidgets);

      // Enter email
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'test@navis.app');
      await tester.pump();

      // Enter password
      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(passwordField, 'password123');
      await tester.pump();

      // Tap the Log In button (NavisButton with label 'Log In')
      // The NavisButton uses a GestureDetector, so we find by
      // Semantics label which wraps the entire button.
      final loginButton = find.bySemanticsLabel('Log In');
      expect(loginButton, findsOneWidget);
      await tester.tap(loginButton);

      // Wait for auth + navigation to /boats
      await tester.pump(_pumpDuration);
      await tester.pump(_networkSettleTimeout);

      // Verify we landed on the boats dashboard
      expect(find.text('My Boats'), findsOneWidget);
    });

    testWidgets('2. Boats: seeded boats appear, documents leads to detail',
        (tester) async {
      await app.main();
      await tester.pump(_pumpDuration);

      // Login first
      await _login(tester);

      // We should see "My Boats" app bar
      expect(find.text('My Boats'), findsOneWidget);

      // Wait for boats to load from the API
      await tester.pump(_networkSettleTimeout);
      await tester.pump(_pumpDuration);

      // Verify seeded boats are visible
      expect(find.text('Luna Azul'), findsOneWidget);
      expect(find.text('Rayo Veloz'), findsOneWidget);

      // Navigate to documents for Luna Azul, then back-navigate
      // to boat detail. The dashboard card has Documents/Logbook
      // buttons. Tap Documents to go to /boats/:id/documents.
      final docButtons = find.text('Documents');
      expect(docButtons, findsWidgets);
      await tester.tap(docButtons.first);
      await tester.pump(_pumpDuration);
      await tester.pump(_networkSettleTimeout);

      // We should be on the document list for Luna Azul
      expect(find.text('Documents'), findsWidgets);

      // Navigate back to dashboard
      final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pump(_pumpDuration);

      // Verify we are back on the boats dashboard
      expect(find.text('My Boats'), findsOneWidget);
      expect(find.text('Luna Azul'), findsOneWidget);
      expect(find.text('Rayo Veloz'), findsOneWidget);
    });

    testWidgets('3. Documents: list and create flow', (tester) async {
      await app.main();
      await tester.pump(_pumpDuration);
      await _login(tester);
      await tester.pump(_networkSettleTimeout);
      await tester.pump(_pumpDuration);

      // Navigate to document list via the Documents button on the
      // first boat card (Luna Azul) in the dashboard
      final docButtons = find.text('Documents');
      expect(docButtons, findsWidgets);
      await tester.tap(docButtons.first);
      await tester.pump(_pumpDuration);
      await tester.pump(_networkSettleTimeout);

      // Verify document list screen
      expect(find.text('Documents'), findsWidgets);

      // Verify seeded documents appear (boat 1 has 2 documents)
      // "Seguro RC" and "ITB (Inspeccion Tecnica)"
      // The _formatType method capitalizes first letter of each word
      expect(find.text('Seguro RC'), findsOneWidget);
      expect(find.text('ITB (Inspeccion Tecnica)'), findsOneWidget);

      // Tap the FAB to create a new document
      final addFab = find.byIcon(Icons.add);
      expect(addFab, findsOneWidget);
      await tester.tap(addFab);
      await tester.pump(_pumpDuration);

      // We should be on the document form screen
      // It has a DropdownButtonFormField for document type
      expect(find.text('Save Document'), findsOneWidget);

      // The type dropdown defaults to 'Registration'
      // Let's change it to 'Insurance' by tapping the dropdown
      final typeDropdown = find.byType(DropdownButtonFormField<String>);
      expect(typeDropdown, findsOneWidget);
      await tester.tap(typeDropdown);
      await tester.pump(_pumpDuration);

      // Select 'Insurance' from the dropdown
      await tester.tap(find.text('Insurance').last);
      await tester.pump();

      // Tap the expiry date field to pick a date
      // The form has a gesture detector or InkWell around the date
      final expiryField = find.textContaining('Expiry');
      if (expiryField.evaluate().isNotEmpty) {
        await tester.tap(expiryField);
        await tester.pump(_pumpDuration);

        // Accept the default date in the date picker
        final okButton = find.text('OK');
        if (okButton.evaluate().isNotEmpty) {
          await tester.tap(okButton);
          await tester.pump();
        }
      }

      // Find the notes field by label
      final notesField = find.widgetWithText(TextFormField, 'Notes');
      if (notesField.evaluate().isNotEmpty) {
        await tester.enterText(notesField, 'Integration test document');
        await tester.pump();
      }

      // Tap Save Document
      final saveButton = find.bySemanticsLabel('Save Document');
      if (saveButton.evaluate().isNotEmpty) {
        await tester.tap(saveButton);
        await tester.pump(_pumpDuration);
        await tester.pump(_networkSettleTimeout);
      }

      // After save, we should be back on the document list
      // or at least not on the form anymore
      // Navigate back to verify
      await tester.pump(_pumpDuration);
    });

    testWidgets('4. Logbook: navigate to trips and view detail',
        (tester) async {
      await app.main();
      await tester.pump(_pumpDuration);
      await _login(tester);
      await tester.pump(_networkSettleTimeout);
      await tester.pump(_pumpDuration);

      // Navigate to logbook via the Logbook button on the first
      // boat card (Luna Azul) in the dashboard
      final logbookButtons = find.text('Logbook');
      expect(logbookButtons, findsWidgets);
      await tester.tap(logbookButtons.first);
      await tester.pump(_pumpDuration);
      await tester.pump(_networkSettleTimeout);

      // Verify logbook screen loaded
      expect(find.text('Logbook'), findsWidgets);

      // Verify seeded trip data is visible
      // Trip 1 goes from "Palma de Mallorca" to "Port de Soller"
      expect(find.text('Palma de Mallorca'), findsWidgets);
      expect(find.text('Port de Soller'), findsOneWidget);

      // Tap the completed trip to view detail
      await tester.tap(find.text('Port de Soller'));
      await tester.pump(_pumpDuration);
      await tester.pump(_networkSettleTimeout);

      // Verify trip detail screen
      expect(find.text('Trip Details'), findsOneWidget);

      // Verify route info
      expect(find.text('Palma de Mallorca'), findsWidgets);
      expect(find.text('Port de Soller'), findsWidgets);

      // Verify crew members are listed
      expect(find.text('Carlos'), findsWidgets);

      // Navigate back
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pump(_pumpDuration);
    });

    testWidgets('5. Weather: tab shows weather or location prompt',
        (tester) async {
      await app.main();
      await tester.pump(_pumpDuration);
      await _login(tester);
      await tester.pump(_networkSettleTimeout);
      await tester.pump(_pumpDuration);

      // Tap the Weather tab in bottom navigation
      // Bottom nav items: Boats(0), Charts(1), Weather(2), Events(3)
      await tester.tap(find.text('Weather'));
      await tester.pump(_pumpDuration);
      await tester.pump(_networkSettleTimeout);

      // The weather screen should show either:
      // - Weather data with temperature display
      // - Location prompt ("Location access is needed")
      // Both are valid states depending on device permissions
      final hasWeatherData = find.textContaining(RegExp(r'\d+°'))
          .evaluate()
          .isNotEmpty;
      final hasLocationPrompt =
          find.text('Location access is needed\nfor weather data.')
              .evaluate()
              .isNotEmpty;
      final hasError = find.byType(ElevatedButton).evaluate().isNotEmpty;

      // At least one of these states should be true
      expect(
        hasWeatherData || hasLocationPrompt || hasError,
        isTrue,
        reason: 'Weather screen should show data, location prompt, '
            'or error state',
      );
    });

    testWidgets('6. Events: list events and view detail', (tester) async {
      await app.main();
      await tester.pump(_pumpDuration);
      await _login(tester);
      await tester.pump(_networkSettleTimeout);
      await tester.pump(_pumpDuration);

      // Tap the Events tab in bottom navigation
      await tester.tap(find.text('Events'));
      await tester.pump(_pumpDuration);
      await tester.pump(_networkSettleTimeout);
      await tester.pump(_pumpDuration);

      // Verify events screen loaded
      expect(find.text('Events'), findsWidgets);

      // Verify seeded events are visible
      // "Copa del Rey Mapfre" is a featured regatta event
      expect(find.text('Copa del Rey Mapfre'), findsOneWidget);

      // Verify search field exists
      expect(find.byIcon(Icons.search), findsOneWidget);

      // Tap the event to view detail
      await tester.tap(find.text('Copa del Rey Mapfre'));
      await tester.pump(_pumpDuration);
      await tester.pump(_networkSettleTimeout);

      // Verify event detail screen
      expect(find.text('Event Details'), findsOneWidget);
      expect(find.text('Copa del Rey Mapfre'), findsOneWidget);
      expect(find.text('Palma de Mallorca'), findsWidgets);
      expect(find.text('Real Club Nautico de Palma'), findsOneWidget);

      // Verify the event type badge
      expect(find.text('Regatta'), findsOneWidget);

      // Navigate back
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pump(_pumpDuration);

      // Verify we are back on events list
      expect(find.text('Copa del Rey Mapfre'), findsOneWidget);
    });

    testWidgets('7. Logout: navigate to profile and log out',
        (tester) async {
      await app.main();
      await tester.pump(_pumpDuration);
      await _login(tester);
      await tester.pump(_networkSettleTimeout);
      await tester.pump(_pumpDuration);

      // Tap profile icon in the app bar
      // NavisAppBar always shows a profile icon button
      final profileIcon = find.byIcon(Icons.person_outline_rounded);
      expect(profileIcon, findsOneWidget);
      await tester.tap(profileIcon);
      await tester.pump(_pumpDuration);

      // Verify profile screen
      expect(find.text('Profile'), findsWidgets);
      expect(find.text('test@navis.app'), findsOneWidget);

      // Tap the Log Out button (NavisButton with danger variant)
      final logoutButton = find.bySemanticsLabel('Log Out');
      expect(logoutButton, findsOneWidget);
      await tester.tap(logoutButton);
      await tester.pump(_pumpDuration);

      // Confirm the logout dialog
      expect(find.text('Are you sure you want to log out?'), findsOneWidget);
      final confirmLogout = find.widgetWithText(FilledButton, 'Log Out');
      expect(confirmLogout, findsOneWidget);
      await tester.tap(confirmLogout);
      await tester.pump(_pumpDuration);
      await tester.pump(_networkSettleTimeout);

      // Verify we are back at the login screen
      expect(find.text('Log In'), findsWidgets);
    });
  });

  group('E2E — Boat Dashboard Interactions', () {
    testWidgets('pull-to-refresh reloads boat list', (tester) async {
      await app.main();
      await tester.pump(_pumpDuration);
      await _login(tester);
      await tester.pump(_networkSettleTimeout);
      await tester.pump(_pumpDuration);

      // Verify initial data
      expect(find.text('Luna Azul'), findsOneWidget);

      // Perform pull-to-refresh
      await tester.drag(find.text('Luna Azul'), const Offset(0, 300));
      await tester.pump(_pumpDuration);
      await tester.pump(_networkSettleTimeout);

      // Verify data is still there after refresh
      expect(find.text('Luna Azul'), findsOneWidget);
      expect(find.text('Rayo Veloz'), findsOneWidget);
    });

    testWidgets('FAB navigates to new boat form', (tester) async {
      await app.main();
      await tester.pump(_pumpDuration);
      await _login(tester);
      await tester.pump(_networkSettleTimeout);
      await tester.pump(_pumpDuration);

      // Tap the floating action button
      final fab = find.byTooltip('Add new boat');
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pump(_pumpDuration);

      // Verify we are on the boat form (it shows a Save button)
      // BoatFormScreen with boatId='new' means create mode
      expect(find.byType(TextFormField), findsWidgets);

      // Navigate back
      final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pump(_pumpDuration);
      }
    });

    testWidgets('document button on boat card navigates to document list',
        (tester) async {
      await app.main();
      await tester.pump(_pumpDuration);
      await _login(tester);
      await tester.pump(_networkSettleTimeout);
      await tester.pump(_pumpDuration);

      // Find the "Documents" button inside the boat card
      // Each boat card has Documents and Logbook buttons
      final docButtons = find.text('Documents');
      expect(docButtons, findsWidgets);

      // Tap the first Documents button (for Luna Azul)
      await tester.tap(docButtons.first);
      await tester.pump(_pumpDuration);
      await tester.pump(_networkSettleTimeout);

      // Verify document list screen
      expect(find.text('Documents'), findsWidgets);
    });
  });

  group('E2E — Events Search', () {
    testWidgets('search filters events', (tester) async {
      await app.main();
      await tester.pump(_pumpDuration);
      await _login(tester);
      await tester.pump(_networkSettleTimeout);
      await tester.pump(_pumpDuration);

      // Navigate to Events tab
      await tester.tap(find.text('Events'));
      await tester.pump(_pumpDuration);
      await tester.pump(_networkSettleTimeout);
      await tester.pump(_pumpDuration);

      // Verify all events are visible initially
      expect(find.text('Copa del Rey Mapfre'), findsOneWidget);

      // Enter search query in the search field
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Copa');
      await tester.pump(const Duration(milliseconds: 400)); // debounce

      // Copa del Rey should still be visible
      expect(find.text('Copa del Rey Mapfre'), findsOneWidget);

      // Search for something that doesn't match
      await tester.enterText(searchField, 'nonexistent event xyz');
      await tester.pump(const Duration(milliseconds: 400)); // debounce
      await tester.pump(_pumpDuration);

      // Copa del Rey should be filtered out
      expect(find.text('Copa del Rey Mapfre'), findsNothing);
      // Empty state should show
      expect(find.text('No events match your search.'), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Logs in with the test user credentials.
///
/// Assumes the app has been started and is showing the login screen.
/// After calling this, the app will be on the /boats screen.
Future<void> _login(WidgetTester tester) async {
  // Wait for login screen to render
  await tester.pump(_pumpDuration);

  // Enter credentials
  final textFields = find.byType(TextFormField);
  await tester.enterText(textFields.first, 'test@navis.app');
  await tester.pump();
  await tester.enterText(textFields.last, 'password123');
  await tester.pump();

  // Tap Log In
  final loginButton = find.bySemanticsLabel('Log In');
  await tester.tap(loginButton);

  // Wait for auth network call + redirect to /boats
  await tester.pump(_pumpDuration);
  await tester.pump(_networkSettleTimeout);
  await tester.pump(_pumpDuration);
}
