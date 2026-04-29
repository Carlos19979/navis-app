import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/core/analytics/analytics_service.dart';
import 'package:navis_mobile/core/database/local_database.dart';
import 'package:navis_mobile/features/auth/data/auth_repository.dart';
import 'package:navis_mobile/features/auth/domain/auth_state.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:navis_mobile/features/profile/presentation/screens/settings_screen.dart';

// --- Mocks ---

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockLocalDatabase extends Mock implements LocalDatabase {}

class MockAuthNotifier extends StateNotifier<AuthState>
    with Mock
    implements AuthNotifier {
  MockAuthNotifier([AuthState? initial])
      : super(initial ?? const AuthState.unauthenticated());

  void setState(AuthState newState) => state = newState;
}

class FakeRoute extends Fake implements Route<dynamic> {}

void main() {
  late MockAuthNotifier mockAuthNotifier;
  late MockAuthRepository mockAuthRepository;
  late MockAnalyticsService mockAnalyticsService;
  late MockLocalDatabase mockLocalDatabase;

  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  setUp(() {
    mockAuthNotifier = MockAuthNotifier();
    mockAuthRepository = MockAuthRepository();
    mockAnalyticsService = MockAnalyticsService();
    mockLocalDatabase = MockLocalDatabase();
  });

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget buildSettingsScreen({bool isDarkMode = true}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((_) => mockAuthNotifier),
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        analyticsProvider.overrideWithValue(mockAnalyticsService),
        localDatabaseProvider.overrideWithValue(mockLocalDatabase),
        themeModeProvider.overrideWith((ref) => isDarkMode),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/settings',
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, __) => const SettingsScreen(),
            ),
            GoRoute(
              path: '/login',
              builder: (_, __) =>
                  const Scaffold(body: Text('Login Page')),
            ),
          ],
        ),
      ),
    );
  }

  group('SettingsScreen', () {
    group('rendering', () {
      testWidgets('renders without errors', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.byType(SettingsScreen), findsOneWidget);
      });

      testWidgets('displays Settings title in app bar',
          (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('Settings'), findsOneWidget);
      });
    });

    group('appearance section', () {
      testWidgets('displays APPEARANCE section header', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('APPEARANCE'), findsOneWidget);
      });

      testWidgets('displays Dark Mode toggle', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('Dark Mode'), findsOneWidget);
        expect(find.text('Use dark theme'), findsOneWidget);
        expect(find.byType(SwitchListTile), findsWidgets);
      });

      testWidgets('dark mode switch is on by default', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen(isDarkMode: true));
        await tester.pumpAndSettle();

        final switchTile = tester.widgetList<SwitchListTile>(
          find.byType(SwitchListTile),
        );
        // First SwitchListTile is the dark mode toggle
        expect(switchTile.first.value, isTrue);
      });

      testWidgets('dark mode switch is off when set to false',
          (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen(isDarkMode: false));
        await tester.pumpAndSettle();

        final switchTile = tester.widgetList<SwitchListTile>(
          find.byType(SwitchListTile),
        );
        expect(switchTile.first.value, isFalse);
      });

      testWidgets('toggling dark mode changes switch state',
          (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen(isDarkMode: true));
        await tester.pumpAndSettle();

        // Find the dark mode switch by looking for the SwitchListTile
        // containing "Dark Mode"
        final darkModeSwitch = find.ancestor(
          of: find.text('Dark Mode'),
          matching: find.byType(SwitchListTile),
        );

        await tester.tap(darkModeSwitch);
        await tester.pumpAndSettle();

        // After toggle, the switch should be off
        final switchTile = tester.widgetList<SwitchListTile>(
          find.byType(SwitchListTile),
        );
        expect(switchTile.first.value, isFalse);
      });

      testWidgets('toggling dark mode off then on again',
          (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen(isDarkMode: true));
        await tester.pumpAndSettle();

        final darkModeSwitch = find.ancestor(
          of: find.text('Dark Mode'),
          matching: find.byType(SwitchListTile),
        );

        // Toggle off
        await tester.tap(darkModeSwitch);
        await tester.pumpAndSettle();

        // Toggle back on
        await tester.tap(darkModeSwitch);
        await tester.pumpAndSettle();

        final switchTile = tester.widgetList<SwitchListTile>(
          find.byType(SwitchListTile),
        );
        expect(switchTile.first.value, isTrue);
      });
    });

    group('language section', () {
      testWidgets('displays LANGUAGE section header', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('LANGUAGE'), findsOneWidget);
      });

      testWidgets('displays Language option with English value',
          (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('Language'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
      });
    });

    group('notifications section', () {
      testWidgets('displays NOTIFICATIONS section header',
          (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('NOTIFICATIONS'), findsOneWidget);
      });

      testWidgets('displays Document Expiry Alerts toggle',
          (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(
          find.text('Document Expiry Alerts'),
          findsOneWidget,
        );
        expect(
          find.text('Get notified before documents expire'),
          findsOneWidget,
        );
      });

      testWidgets('displays Event Reminders toggle', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('Event Reminders'), findsOneWidget);
        expect(
          find.text('Get reminded about upcoming events'),
          findsOneWidget,
        );
      });
    });

    group('data and storage section', () {
      testWidgets('displays DATA & STORAGE section header',
          (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('DATA & STORAGE'), findsOneWidget);
      });

      testWidgets('displays Clear Image Cache option', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('Clear Image Cache'), findsOneWidget);
        expect(
          find.text('Remove cached photos and map tiles'),
          findsOneWidget,
        );
      });

      testWidgets('displays Clear Offline Data option', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('Clear Offline Data'), findsOneWidget);
        expect(
          find.text('Remove cached boats, documents, trips'),
          findsOneWidget,
        );
      });

      testWidgets('clear offline data calls localDatabase.clearTable',
          (tester) async {
        when(() => mockLocalDatabase.clearTable(any()))
            .thenAnswer((_) async {});

        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Clear Offline Data'));
        await tester.pumpAndSettle();

        verify(() => mockLocalDatabase.clearTable('boats')).called(1);
        verify(() => mockLocalDatabase.clearTable('documents'))
            .called(1);
        verify(() => mockLocalDatabase.clearTable('trips')).called(1);
      });

      testWidgets(
          'shows snackbar after clearing offline data',
          (tester) async {
        when(() => mockLocalDatabase.clearTable(any()))
            .thenAnswer((_) async {});

        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Clear Offline Data'));
        await tester.pumpAndSettle();

        expect(
          find.text('Offline data cleared'),
          findsOneWidget,
        );
      });

      testWidgets('displays storage icons', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.cached), findsOneWidget);
        expect(find.byIcon(Icons.delete_sweep), findsOneWidget);
      });
    });

    group('account section', () {
      testWidgets('displays ACCOUNT section header', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('ACCOUNT'), findsOneWidget);
      });

      testWidgets('displays Log Out button', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('Log Out'), findsOneWidget);
        expect(find.byIcon(Icons.logout), findsOneWidget);
      });

      testWidgets('tapping Log Out opens confirmation dialog',
          (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Log Out'));
        await tester.pumpAndSettle();

        expect(
          find.text('Are you sure you want to log out?'),
          findsOneWidget,
        );
        expect(find.text('Cancel'), findsOneWidget);
      });

      testWidgets('cancel closes the logout dialog', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Log Out'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(
          find.text('Are you sure you want to log out?'),
          findsNothing,
        );
      });

      testWidgets('confirming logout calls auth notifier logout',
          (tester) async {
        when(() => mockAuthNotifier.logout())
            .thenAnswer((_) async {});

        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Log Out'));
        await tester.pumpAndSettle();

        final dialogLogout = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Log Out'),
        );
        await tester.tap(dialogLogout);
        await tester.pumpAndSettle();

        verify(() => mockAuthNotifier.logout()).called(1);
      });
    });

    group('overall structure', () {
      testWidgets('has all five section headers', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        expect(find.text('APPEARANCE'), findsOneWidget);
        expect(find.text('LANGUAGE'), findsOneWidget);
        expect(find.text('NOTIFICATIONS'), findsOneWidget);
        expect(find.text('DATA & STORAGE'), findsOneWidget);
        expect(find.text('ACCOUNT'), findsOneWidget);
      });

      testWidgets('sections are scrollable', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreen());
        await tester.pumpAndSettle();

        // The screen uses a ListView which is scrollable
        expect(find.byType(ListView), findsOneWidget);
      });
    });
  });
}
