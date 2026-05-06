import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/core/analytics/analytics_service.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/core/network/notification_service.dart';
import 'package:navis_mobile/features/auth/data/auth_repository.dart';
import 'package:navis_mobile/features/auth/domain/auth_state.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:navis_mobile/features/profile/presentation/screens/profile_screen.dart';

const _default = Object();

// --- Mocks ---

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockNotificationService extends Mock implements NotificationService {
  @override
  Future<void> unregisterDevice() async {}
}

class MockAuthNotifier extends StateNotifier<AuthState>
    with Mock
    implements AuthNotifier {
  MockAuthNotifier([AuthState? initial])
      : super(initial ?? const AuthState.unauthenticated());

  void setState(AuthState newState) => state = newState;

  bool logoutCalled = false;

  @override
  Future<void> logout() async {
    logoutCalled = true;
    state = const AuthState.unauthenticated();
  }
}

class FakeRoute extends Fake implements Route<dynamic> {}

void main() {
  late MockAuthNotifier mockAuthNotifier;
  late MockAuthRepository mockAuthRepository;
  late MockAnalyticsService mockAnalyticsService;
  late MockNotificationService mockNotificationService;

  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  setUp(() {
    mockAuthNotifier = MockAuthNotifier();
    mockAuthRepository = MockAuthRepository();
    mockAnalyticsService = MockAnalyticsService();
    mockNotificationService = MockNotificationService();
  });

  UserProfile testProfile({
    String id = 'user-1',
    String email = 'test@navis.app',
    String? displayName = 'Test User',
    String? avatarUrl,
    Object? createdAt = _default,
  }) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName,
      avatarUrl: avatarUrl,
      createdAt: createdAt == _default
          ? DateTime(2026, 1, 15)
          : createdAt as DateTime?,
    );
  }

  Widget buildProfileScreen({UserProfile? profile}) {
    return ProviderScope(
      overrides: [
        profileProvider.overrideWithValue(profile ?? testProfile()),
        authProvider.overrideWith((_) => mockAuthNotifier),
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        analyticsProvider.overrideWithValue(mockAnalyticsService),
        notificationServiceProvider.overrideWithValue(mockNotificationService),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/profile',
          routes: [
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen(),
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
  }

  group('ProfileScreen', () {
    group('rendering', () {
      testWidgets('renders without errors', (tester) async {
        await tester.pumpWidget(buildProfileScreen());
        await tester.pumpAndSettle();

        expect(find.byType(ProfileScreen), findsOneWidget);
      });

      testWidgets('displays user display name', (tester) async {
        await tester.pumpWidget(buildProfileScreen());
        await tester.pumpAndSettle();

        expect(find.text('Test User'), findsWidgets);
      });

      testWidgets('displays user email', (tester) async {
        await tester.pumpWidget(buildProfileScreen());
        await tester.pumpAndSettle();

        expect(find.text('test@navis.app'), findsOneWidget);
      });

      testWidgets('displays avatar initial from display name', (tester) async {
        await tester.pumpWidget(buildProfileScreen());
        await tester.pumpAndSettle();

        // The avatar shows the first letter of the display name
        expect(find.text('T'), findsOneWidget);
      });

      testWidgets('displays avatar initial from email when no display name',
          (tester) async {
        await tester.pumpWidget(buildProfileScreen(
          profile: testProfile(
            displayName: null,
            email: 'carlos@navis.app',
          ),
        ));
        await tester.pumpAndSettle();

        // First letter of email
        expect(find.text('C'), findsOneWidget);
      });

      testWidgets('displays fallback name when display name is null',
          (tester) async {
        await tester.pumpWidget(buildProfileScreen(
          profile: testProfile(displayName: null),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Navis User'), findsOneWidget);
      });

      testWidgets('displays Profile title in app bar', (tester) async {
        await tester.pumpWidget(buildProfileScreen());
        await tester.pumpAndSettle();

        expect(find.text('Profile'), findsOneWidget);
      });

      testWidgets('displays member since date when createdAt is set',
          (tester) async {
        await tester.pumpWidget(buildProfileScreen(
          profile: testProfile(
            createdAt: DateTime(2026, 1, 15),
          ),
        ));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Member since'),
          findsOneWidget,
        );
      });
    });

    group('menu items', () {
      testWidgets('displays Settings menu item', (tester) async {
        await tester.pumpWidget(buildProfileScreen());
        await tester.pumpAndSettle();

        expect(find.text('Settings'), findsOneWidget);
        expect(
          find.byIcon(Icons.settings_outlined),
          findsOneWidget,
        );
      });

      testWidgets('displays Help & Support menu item', (tester) async {
        await tester.pumpWidget(buildProfileScreen());
        await tester.pumpAndSettle();

        expect(find.text('Help & Support'), findsOneWidget);
        expect(find.byIcon(Icons.help_outline), findsOneWidget);
      });

      testWidgets('displays About Navis menu item', (tester) async {
        await tester.pumpWidget(buildProfileScreen());
        await tester.pumpAndSettle();

        expect(find.text('About Navis'), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });

      testWidgets('all menu items have chevron trailing icon', (tester) async {
        await tester.pumpWidget(buildProfileScreen());
        await tester.pumpAndSettle();

        // Each _ProfileTile has a chevron_right icon
        expect(
          find.byIcon(Icons.chevron_right),
          findsNWidgets(3),
        );
      });
    });

    group('logout', () {
      testWidgets('displays Log Out button', (tester) async {
        await tester.pumpWidget(buildProfileScreen());
        await tester.pumpAndSettle();

        expect(find.text('Log Out'), findsOneWidget);
        expect(find.byIcon(Icons.logout), findsOneWidget);
      });

      testWidgets('tapping Log Out opens confirmation dialog', (tester) async {
        await tester.pumpWidget(buildProfileScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Log Out'));
        await tester.pumpAndSettle();

        expect(
          find.text('Are you sure you want to log out?'),
          findsOneWidget,
        );
        expect(find.text('Cancel'), findsOneWidget);
        // Dialog has title "Log Out" + confirm button "Log Out" + screen button
        expect(find.text('Log Out'), findsNWidgets(3));
      });

      testWidgets('cancel closes the logout dialog', (tester) async {
        await tester.pumpWidget(buildProfileScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Log Out'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Dialog should be dismissed
        expect(
          find.text('Are you sure you want to log out?'),
          findsNothing,
        );
      });

      testWidgets('confirming logout calls auth notifier logout',
          (tester) async {
        await tester.pumpWidget(buildProfileScreen());
        await tester.pumpAndSettle();

        // Tap the logout button on the screen
        await tester.tap(find.text('Log Out'));
        await tester.pumpAndSettle();

        final dialogLogout = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Log Out'),
        );

        await tester.tap(dialogLogout);
        await tester.pumpAndSettle();

        expect(mockAuthNotifier.logoutCalled, isTrue);
      });
    });

    group('null profile state', () {
      testWidgets('shows not logged in message when profile is null',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileProvider.overrideWithValue(null),
              authProvider.overrideWith((_) => mockAuthNotifier),
              authRepositoryProvider.overrideWithValue(mockAuthRepository),
              analyticsProvider.overrideWithValue(mockAnalyticsService),
              notificationServiceProvider
                  .overrideWithValue(mockNotificationService),
            ],
            child: const MaterialApp(
              home: ProfileScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Not logged in'), findsOneWidget);
      });

      testWidgets('does not show profile details when profile is null',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileProvider.overrideWithValue(null),
              authProvider.overrideWith((_) => mockAuthNotifier),
              authRepositoryProvider.overrideWithValue(mockAuthRepository),
              analyticsProvider.overrideWithValue(mockAnalyticsService),
              notificationServiceProvider
                  .overrideWithValue(mockNotificationService),
            ],
            child: const MaterialApp(
              home: ProfileScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Settings'), findsNothing);
        expect(find.text('Log Out'), findsNothing);
      });
    });

    group('different profiles', () {
      testWidgets('renders profile with long display name', (tester) async {
        await tester.pumpWidget(buildProfileScreen(
          profile: testProfile(
            displayName: 'Captain Juan Carlos Rodriguez de la Mar',
          ),
        ));
        await tester.pumpAndSettle();

        expect(
          find.text('Captain Juan Carlos Rodriguez de la Mar'),
          findsOneWidget,
        );
      });

      testWidgets('renders profile without createdAt date', (tester) async {
        await tester.pumpWidget(buildProfileScreen(
          profile: testProfile(createdAt: null),
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('Member since'), findsNothing);
      });
    });
  });
}
