import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:navis_mobile/core/analytics/analytics_service.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/core/config/settings_service.dart';
import 'package:navis_mobile/core/database/local_database.dart';
import 'package:navis_mobile/features/auth/data/auth_repository.dart';
import 'package:navis_mobile/features/auth/domain/auth_state.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/features/notifications/domain/entities/app_notification.dart';
import 'package:navis_mobile/features/notifications/domain/repositories/notification_feed_repository.dart';
import 'package:navis_mobile/features/notifications/presentation/providers/notification_feed_provider.dart';
import 'package:navis_mobile/features/profile/data/account_provider.dart';
import 'package:navis_mobile/features/profile/presentation/screens/settings_screen.dart';
import 'package:navis_mobile/features/profile/presentation/widgets/export_data_tile.dart';

import '../../helpers/plan.dart';

// --- Mocks ---

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAccountRepository extends Mock implements AccountRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockLocalDatabase extends Mock implements LocalDatabase {}

class MockNotificationFeedRepository extends Mock
    implements NotificationFeedRepository {}

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
  late MockAccountRepository mockAccountRepository;
  late MockNotificationFeedRepository mockFeedRepository;

  /// All five categories enabled — what a user who never touched the toggles
  /// gets from the API.
  List<NotificationPreference> allEnabled() => [
        for (final category in NotificationCategory.values)
          NotificationPreference(category: category, enabled: true),
      ];

  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  setUp(() {
    mockAuthNotifier = MockAuthNotifier();
    mockAuthRepository = MockAuthRepository();
    mockAnalyticsService = MockAnalyticsService();
    mockLocalDatabase = MockLocalDatabase();
    mockAccountRepository = MockAccountRepository();
    when(() => mockAccountRepository.getMe())
        .thenAnswer((_) async => makeAccount());

    // The notification card is server-backed, so every test in this file needs
    // it stubbed — otherwise pumping Settings would reach the real ApiClient.
    mockFeedRepository = MockNotificationFeedRepository();
    when(() => mockFeedRepository.getPreferences())
        .thenAnswer((_) async => allEnabled());
    when(() => mockFeedRepository.setPreferences(any())).thenAnswer(
      (invocation) async =>
          invocation.positionalArguments.first as List<NotificationPreference>,
    );
  });

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget buildSettingsScreenWithPrefs({
    bool isDarkMode = true,
    List<Override> extraOverrides = const [],
  }) {
    SharedPreferences.setMockInitialValues({
      'settings_theme_mode': isDarkMode ? 'dark' : 'light',
    });

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        return ProviderScope(
          overrides: [
            authProvider.overrideWith((_) => mockAuthNotifier),
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
            analyticsProvider.overrideWithValue(mockAnalyticsService),
            localDatabaseProvider.overrideWithValue(mockLocalDatabase),
            sharedPreferencesProvider.overrideWithValue(snapshot.data!),
            accountRepositoryProvider.overrideWithValue(
              mockAccountRepository,
            ),
            notificationFeedRepositoryProvider.overrideWithValue(
              mockFeedRepository,
            ),
            ...extraOverrides,
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/settings',
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (_, __) => const Scaffold(
                    body: SingleChildScrollView(
                      child: AccountSettingsSections(),
                    ),
                  ),
                ),
                GoRoute(
                  path: '/login',
                  builder: (_, __) => const Scaffold(body: Text('Login Page')),
                ),
              ],
            ),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('es'),
            ],
          ),
        );
      },
    );
  }

  group('SettingsScreen', () {
    group('rendering', () {
      testWidgets('renders without errors', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        expect(find.byType(AccountSettingsSections), findsOneWidget);
      });

      testWidgets('shows its section headings', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        // There is no «Settings» title any more: these are sections of the
        // Profile tab, not a screen with a bar of its own.
        expect(find.text('APPEARANCE'), findsOneWidget);
        expect(find.text('LANGUAGE'), findsOneWidget);
      });
    });

    group('appearance section', () {
      testWidgets('displays APPEARANCE section header', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        expect(find.text('APPEARANCE'), findsOneWidget);
      });

      testWidgets('displays Dark Mode toggle', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        expect(find.text('Dark Mode'), findsOneWidget);
        expect(find.byType(SwitchListTile), findsWidgets);
      });

      testWidgets('dark mode switch is on by default', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        final switchTile = tester.widgetList<SwitchListTile>(
          find.byType(SwitchListTile),
        );
        expect(switchTile.first.value, isTrue);
      });

      testWidgets('dark mode switch is off when set to false', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(
          buildSettingsScreenWithPrefs(isDarkMode: false),
        );
        await tester.pumpAndSettle();

        final switchTile = tester.widgetList<SwitchListTile>(
          find.byType(SwitchListTile),
        );
        expect(switchTile.first.value, isFalse);
      });

      testWidgets('toggling dark mode changes switch state', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        final darkModeSwitch = find.ancestor(
          of: find.text('Dark Mode'),
          matching: find.byType(SwitchListTile),
        );

        await tester.tap(darkModeSwitch);
        await tester.pumpAndSettle();

        final switchTile = tester.widgetList<SwitchListTile>(
          find.byType(SwitchListTile),
        );
        expect(switchTile.first.value, isFalse);
      });
    });

    group('language section', () {
      testWidgets('displays LANGUAGE section header', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        expect(find.text('LANGUAGE'), findsOneWidget);
      });

      testWidgets('displays Language option with System default',
          (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        expect(find.text('Language'), findsOneWidget);
        expect(find.text('System default'), findsOneWidget);
      });
    });

    group('notifications section', () {
      testWidgets('displays NOTIFICATIONS section header', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        expect(find.text('NOTIFICATIONS'), findsOneWidget);
      });

      testWidgets('displays one toggle per notification category',
          (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        // The five server-side categories, each with its explanation.
        expect(find.text('Reminders'), findsOneWidget);
        expect(find.text('Expiring documents and maintenance due'),
            findsOneWidget);
        expect(find.text('Regattas'), findsOneWidget);
        expect(find.text('Clubs and groups'), findsOneWidget);
        expect(find.text('Boat activity'), findsOneWidget);
        expect(find.text('Live events'), findsOneWidget);
        expect(find.byType(SwitchListTile),
            findsNWidgets(NotificationCategory.values.length + 2));
      });

      testWidgets('reflects a muted category as an off switch', (tester) async {
        when(() => mockFeedRepository.getPreferences())
            .thenAnswer((_) async => [
                  for (final category in NotificationCategory.values)
                    NotificationPreference(
                      category: category,
                      enabled: category != NotificationCategory.groupUpdates,
                    ),
                ]);

        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        final groupSwitch = tester.widget<SwitchListTile>(
          find.ancestor(
            of: find.text('Clubs and groups'),
            matching: find.byType(SwitchListTile),
          ),
        );
        expect(groupSwitch.value, isFalse);
      });
    });

    group('data and storage section', () {
      testWidgets('displays DATA & STORAGE section header', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        expect(find.text('DATA & STORAGE'), findsOneWidget);
      });

      testWidgets('displays Clear Image Cache option', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        expect(
          find.text('Clear Image Cache'),
          findsOneWidget,
        );
        expect(
          find.text('Remove cached photos and map tiles'),
          findsOneWidget,
        );
      });

      testWidgets('displays Clear Offline Data option', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        expect(
          find.text('Clear Offline Data'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Remove cached boats, documents, trips',
          ),
          findsOneWidget,
        );
      });

      testWidgets('clear offline data calls localDatabase.clearTable',
          (tester) async {
        when(() => mockLocalDatabase.clearTable(any()))
            .thenAnswer((_) async {});

        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Clear Offline Data'));
        await tester.pumpAndSettle();

        verify(() => mockLocalDatabase.clearTable('boats')).called(1);
        verify(
          () => mockLocalDatabase.clearTable('documents'),
        ).called(1);
        verify(() => mockLocalDatabase.clearTable('trips')).called(1);
      });

      testWidgets('shows snackbar after clearing offline data', (tester) async {
        when(() => mockLocalDatabase.clearTable(any()))
            .thenAnswer((_) async {});

        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Clear Offline Data'));
        await tester.pumpAndSettle();

        expect(
          find.text('Offline data cleared'),
          findsOneWidget,
        );
      });

      testWidgets('displays Export my data option', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        expect(find.text('Export my data'), findsOneWidget);
        expect(
          find.text('Download everything as a JSON file'),
          findsOneWidget,
        );
      });

      testWidgets(
          'export calls the API, shares the file and confirms via snackbar',
          (tester) async {
        when(() => mockAccountRepository.exportData())
            .thenAnswer((_) async => {'boats': <Object>[]});

        final sharedPayloads = <String>[];
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs(
          extraOverrides: [
            exportShareProvider.overrideWithValue((json, origin) async {
              sharedPayloads.add(json);
            }),
          ],
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Export my data'));
        await tester.pumpAndSettle();

        verify(() => mockAccountRepository.exportData()).called(1);
        expect(sharedPayloads, hasLength(1));
        expect(sharedPayloads.single, contains('"boats"'));
        expect(find.text('Export ready to share'), findsOneWidget);
      });

      testWidgets('a failed export shows an error snackbar', (tester) async {
        when(() => mockAccountRepository.exportData())
            .thenThrow(Exception('boom'));

        var shared = false;
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs(
          extraOverrides: [
            exportShareProvider.overrideWithValue((json, origin) async {
              shared = true;
            }),
          ],
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Export my data'));
        await tester.pumpAndSettle();

        expect(shared, isFalse);
        expect(
          find.text('Could not export your data. Try again.'),
          findsOneWidget,
        );
      });

      testWidgets('displays storage icons', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.cached), findsOneWidget);
        expect(
          find.byIcon(Icons.delete_sweep),
          findsOneWidget,
        );
      });
    });

    group('account section', () {
      testWidgets('displays ACCOUNT section header', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        expect(find.text('ACCOUNT'), findsOneWidget);
      });

      testWidgets('displays Log Out button', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        expect(find.text('Log Out'), findsOneWidget);
        expect(find.byIcon(Icons.logout), findsOneWidget);
      });

      testWidgets('tapping Log Out opens confirmation dialog', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
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
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
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
        when(() => mockAuthNotifier.logout()).thenAnswer((_) async {});

        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Log Out'));
        await tester.pumpAndSettle();

        // The surviving log-out is the one that unregisters the push device
        // first, and it confirms with a FilledButton rather than a TextButton.
        final dialogLogout = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Log Out'),
        );
        await tester.tap(dialogLogout);
        await tester.pumpAndSettle();

        verify(() => mockAuthNotifier.logout()).called(1);
      });
    });

    group('language picker', () {
      testWidgets('opens a dialog with the three language options',
          (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Language'));
        await tester.pumpAndSettle();

        expect(find.text('Select Language'), findsOneWidget);
        // Subtitle + dialog option both read "System default".
        expect(find.text('System default'), findsNWidgets(2));
        expect(find.text('English'), findsOneWidget);
        expect(find.text('Español'), findsOneWidget);
      });

      testWidgets('selecting Español updates the locale and persists it',
          (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Language'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Español'));
        await tester.pumpAndSettle();

        // Dialog closed; the subtitle now shows the selected language.
        expect(find.text('Select Language'), findsNothing);
        expect(find.text('Español'), findsOneWidget);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('settings_locale'), 'es');
      });
    });

    group('notification preferences persistence', () {
      testWidgets('turning a category off sends the full set to the API',
          (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        final remindersSwitch = find.ancestor(
          of: find.text('Reminders'),
          matching: find.byType(SwitchListTile),
        );
        await tester.tap(remindersSwitch);
        await tester.pumpAndSettle();

        final sent =
            verify(() => mockFeedRepository.setPreferences(captureAny()))
                .captured
                .single as List<NotificationPreference>;
        // The PUT replaces the set, so all five travel — with only the tapped
        // one disabled.
        expect(sent.length, NotificationCategory.values.length);
        expect(
          sent
              .firstWhere((p) => p.category == NotificationCategory.reminders)
              .enabled,
          isFalse,
        );
        expect(
          sent.where((p) => p.enabled).length,
          NotificationCategory.values.length - 1,
        );
      });
    });

    group('delete account', () {
      Future<void> openDeleteFlow(WidgetTester tester) async {
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete account'));
        await tester.pumpAndSettle();
      }

      testWidgets('step 1 explains the deletion and cancel aborts',
          (tester) async {
        setPhoneSize(tester);
        await openDeleteFlow(tester);

        expect(
          find.textContaining('permanently deletes your account'),
          findsOneWidget,
        );

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('permanently deletes your account'),
          findsNothing,
        );
        verifyNever(() => mockAccountRepository.deleteAccount());
      });

      testWidgets('step 2 requires typing the confirm word, cancel aborts',
          (tester) async {
        setPhoneSize(tester);
        await openDeleteFlow(tester);

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Type DELETE to confirm'), findsOneWidget);

        // Without the confirm word the delete button stays disabled.
        final deleteButton = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Delete'),
        );
        expect(deleteButton.onPressed, isNull);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        verifyNever(() => mockAccountRepository.deleteAccount());
      });

      testWidgets('a failed deletion shows an error snackbar', (tester) async {
        when(() => mockAccountRepository.deleteAccount())
            .thenThrow(Exception('boom'));

        setPhoneSize(tester);
        await openDeleteFlow(tester);

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'DELETE');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();

        verify(() => mockAccountRepository.deleteAccount()).called(1);
        expect(
          find.text('Could not delete the account. Try again.'),
          findsOneWidget,
        );
      });
    });

    group('overall structure', () {
      testWidgets('has all five section headers', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        expect(find.text('APPEARANCE'), findsOneWidget);
        expect(find.text('LANGUAGE'), findsOneWidget);
        expect(find.text('NOTIFICATIONS'), findsOneWidget);
        expect(
          find.text('DATA & STORAGE'),
          findsOneWidget,
        );
        expect(find.text('ACCOUNT'), findsOneWidget);
      });

      testWidgets('sections are scrollable', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();

        // The sections no longer own the scroll view: they are a column inside
        // the Profile tab's, so this asserts they are *inside* one rather than
        // that they are one.
        expect(
          find.ancestor(
            of: find.byType(AccountSettingsSections),
            matching: find.byType(Scrollable),
          ),
          findsWidgets,
        );
      });
    });

    // The pre-trip checklist is optional now, and the answer is remembered, so
    // Settings is the way back for anyone who chose to skip it for good.
    group('pre-trip checklist', () {
      Future<void> openSettings(WidgetTester tester) async {
        await tester.pumpWidget(buildSettingsScreenWithPrefs());
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Checklist before setting sail'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      }

      testWidgets('shows that the trip start asks by default', (tester) async {
        setPhoneSize(tester);
        await openSettings(tester);

        expect(
          find.text("You'll be asked when a trip starts"),
          findsOneWidget,
        );
      });

      testWidgets('turning it off persists the skip choice', (tester) async {
        setPhoneSize(tester);
        await openSettings(tester);

        await tester.tap(find.text('Checklist before setting sail'));
        await tester.pumpAndSettle();

        expect(
          find.text('Skipped — turn on to be asked again'),
          findsOneWidget,
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('settings_pretrip_checklist'), 'skip');
      });

      testWidgets('turning it back on asks again on the next trip',
          (tester) async {
        setPhoneSize(tester);
        await openSettings(tester);

        await tester.tap(find.text('Checklist before setting sail'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Checklist before setting sail'));
        await tester.pumpAndSettle();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('settings_pretrip_checklist'), 'ask');
      });
    });
  });
}
