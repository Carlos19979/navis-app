import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/core/analytics/analytics_service.dart';
import 'package:navis_mobile/features/auth/data/auth_repository.dart';
import 'package:navis_mobile/features/auth/domain/auth_state.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/features/auth/presentation/screens/register_screen.dart';

// --- Mocks ---

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

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

  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  setUp(() {
    mockAuthNotifier = MockAuthNotifier();
    mockAuthRepository = MockAuthRepository();
    mockAnalyticsService = MockAnalyticsService();
  });

  Widget buildRegisterScreen({AuthState? initialState}) {
    if (initialState != null) {
      mockAuthNotifier = MockAuthNotifier(initialState);
    }
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((_) => mockAuthNotifier),
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        analyticsProvider.overrideWithValue(mockAnalyticsService),
      ],
      child: const MaterialApp(home: RegisterScreen()),
    );
  }

  group('RegisterScreen', () {
    group('rendering', () {
      testWidgets('renders without errors', (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        expect(find.byType(RegisterScreen), findsOneWidget);
      });

      testWidgets('displays Create Account title', (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        expect(find.text('Create Account'), findsOneWidget);
      });

      testWidgets('displays subtitle text', (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        expect(
          find.text('JOIN NAVIS AND MANAGE YOUR BOAT'),
          findsOneWidget,
        );
      });

      testWidgets('displays email, password, and confirm password fields',
          (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Confirm Password'), findsOneWidget);
      });

      testWidgets('displays Register button', (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        expect(find.text('Register'), findsOneWidget);
      });

      testWidgets('displays Login link', (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Already have an account?'),
          findsOneWidget,
        );
        expect(find.textContaining('Log In'), findsOneWidget);
      });

      testWidgets('displays sailing icon', (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.sailing), findsOneWidget);
      });
    });

    group('text input', () {
      testWidgets('email field accepts input', (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        final emailField = find.widgetWithText(
          TextFormField,
          'Email',
        );
        await tester.enterText(emailField, 'new@navis.app');
        await tester.pump();

        expect(find.text('new@navis.app'), findsOneWidget);
      });

      testWidgets('password field accepts input', (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        final passwordField = find.widgetWithText(
          TextFormField,
          'Password',
        );
        await tester.enterText(passwordField, 'secret123');
        await tester.pump();

        expect(find.text('secret123'), findsOneWidget);
      });

      testWidgets('confirm password field accepts input',
          (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        final confirmField = find.widgetWithText(
          TextFormField,
          'Confirm Password',
        );
        await tester.enterText(confirmField, 'secret123');
        await tester.pump();

        expect(find.text('secret123'), findsOneWidget);
      });

      testWidgets('password fields are obscured by default',
          (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        final passwordField = find.widgetWithText(
          TextFormField,
          'Password',
        );
        final confirmField = find.widgetWithText(
          TextFormField,
          'Confirm Password',
        );

        final passwordTextField = tester.widget<TextField>(
          find.descendant(
            of: passwordField,
            matching: find.byType(TextField),
          ),
        );
        final confirmTextField = tester.widget<TextField>(
          find.descendant(
            of: confirmField,
            matching: find.byType(TextField),
          ),
        );

        expect(passwordTextField.obscureText, isTrue);
        expect(confirmTextField.obscureText, isTrue);
      });

      testWidgets(
          'password visibility toggle works for password field',
          (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        // Both password fields have visibility icons; there should be 2
        expect(
          find.byIcon(Icons.visibility_outlined),
          findsNWidgets(2),
        );

        // Tap the first visibility icon (password field)
        await tester.tap(find.byIcon(Icons.visibility_outlined).first);
        await tester.pump();

        // One should toggle to off, one remains on
        expect(
          find.byIcon(Icons.visibility_off_outlined),
          findsOneWidget,
        );
        expect(
          find.byIcon(Icons.visibility_outlined),
          findsOneWidget,
        );
      });
    });

    group('form validation', () {
      testWidgets('shows error when email is empty', (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Register'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter your email'), findsOneWidget);
      });

      testWidgets('shows error when email is invalid', (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        final emailField = find.widgetWithText(
          TextFormField,
          'Email',
        );
        await tester.enterText(emailField, 'not-an-email');
        await tester.tap(find.text('Register'));
        await tester.pumpAndSettle();

        expect(
          find.text('Please enter a valid email'),
          findsOneWidget,
        );
      });

      testWidgets('shows error when password is empty', (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        final emailField = find.widgetWithText(
          TextFormField,
          'Email',
        );
        await tester.enterText(emailField, 'test@navis.app');
        await tester.tap(find.text('Register'));
        await tester.pumpAndSettle();

        expect(
          find.text('Please enter a password'),
          findsOneWidget,
        );
      });

      testWidgets('shows error when password is too short',
          (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        final emailField = find.widgetWithText(
          TextFormField,
          'Email',
        );
        final passwordField = find.widgetWithText(
          TextFormField,
          'Password',
        );
        await tester.enterText(emailField, 'test@navis.app');
        await tester.enterText(passwordField, 'abc');
        await tester.tap(find.text('Register'));
        await tester.pumpAndSettle();

        expect(
          find.text('Password must be at least 6 characters'),
          findsOneWidget,
        );
      });

      testWidgets('shows error when confirm password is empty',
          (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        final emailField = find.widgetWithText(
          TextFormField,
          'Email',
        );
        final passwordField = find.widgetWithText(
          TextFormField,
          'Password',
        );
        await tester.enterText(emailField, 'test@navis.app');
        await tester.enterText(passwordField, 'password123');
        await tester.tap(find.text('Register'));
        await tester.pumpAndSettle();

        expect(
          find.text('Please confirm your password'),
          findsOneWidget,
        );
      });

      testWidgets('shows error when passwords do not match',
          (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        final emailField = find.widgetWithText(
          TextFormField,
          'Email',
        );
        final passwordField = find.widgetWithText(
          TextFormField,
          'Password',
        );
        final confirmField = find.widgetWithText(
          TextFormField,
          'Confirm Password',
        );
        await tester.enterText(emailField, 'test@navis.app');
        await tester.enterText(passwordField, 'password123');
        await tester.enterText(confirmField, 'different456');
        await tester.tap(find.text('Register'));
        await tester.pumpAndSettle();

        expect(
          find.text('Passwords do not match'),
          findsOneWidget,
        );
      });

      testWidgets('no validation errors with valid matching input',
          (tester) async {
        when(() => mockAuthNotifier.register(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async {});

        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        final emailField = find.widgetWithText(
          TextFormField,
          'Email',
        );
        final passwordField = find.widgetWithText(
          TextFormField,
          'Password',
        );
        final confirmField = find.widgetWithText(
          TextFormField,
          'Confirm Password',
        );
        await tester.enterText(emailField, 'test@navis.app');
        await tester.enterText(passwordField, 'password123');
        await tester.enterText(confirmField, 'password123');
        await tester.tap(find.text('Register'));
        await tester.pumpAndSettle();

        expect(
          find.text('Please enter your email'),
          findsNothing,
        );
        expect(
          find.text('Passwords do not match'),
          findsNothing,
        );
      });
    });

    group('register action', () {
      testWidgets('calls register on notifier with correct credentials',
          (tester) async {
        when(() => mockAuthNotifier.register(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async {});

        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        final emailField = find.widgetWithText(
          TextFormField,
          'Email',
        );
        final passwordField = find.widgetWithText(
          TextFormField,
          'Password',
        );
        final confirmField = find.widgetWithText(
          TextFormField,
          'Confirm Password',
        );
        await tester.enterText(emailField, 'new@navis.app');
        await tester.enterText(passwordField, 'newpass123');
        await tester.enterText(confirmField, 'newpass123');
        await tester.tap(find.text('Register'));
        await tester.pumpAndSettle();

        verify(() => mockAuthNotifier.register(
              email: 'new@navis.app',
              password: 'newpass123',
            )).called(1);
      });

      testWidgets('does not call register when validation fails',
          (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        // Tap register with empty fields
        await tester.tap(find.text('Register'));
        await tester.pumpAndSettle();

        verifyNever(() => mockAuthNotifier.register(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ));
      });

      testWidgets(
          'does not call register when passwords do not match',
          (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        final emailField = find.widgetWithText(
          TextFormField,
          'Email',
        );
        final passwordField = find.widgetWithText(
          TextFormField,
          'Password',
        );
        final confirmField = find.widgetWithText(
          TextFormField,
          'Confirm Password',
        );
        await tester.enterText(emailField, 'test@navis.app');
        await tester.enterText(passwordField, 'password123');
        await tester.enterText(confirmField, 'mismatch');
        await tester.tap(find.text('Register'));
        await tester.pumpAndSettle();

        verifyNever(() => mockAuthNotifier.register(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ));
      });
    });

    group('error state', () {
      testWidgets('displays error message from auth state',
          (tester) async {
        await tester.pumpWidget(buildRegisterScreen(
          initialState: const AuthState.unauthenticated(
            errorMessage: 'Email already registered',
          ),
        ));
        await tester.pumpAndSettle();

        expect(
          find.text('Email already registered'),
          findsOneWidget,
        );
      });

      testWidgets('displays error icon with error message',
          (tester) async {
        await tester.pumpWidget(buildRegisterScreen(
          initialState: const AuthState.unauthenticated(
            errorMessage: 'Server error',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Server error'), findsOneWidget);
      });

      testWidgets('does not display error when state has no error',
          (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error_outline), findsNothing);
      });
    });

    group('loading state', () {
      testWidgets('shows loading indicator when auth is loading',
          (tester) async {
        await tester.pumpWidget(buildRegisterScreen(
          initialState: const AuthState(status: AuthStatus.loading),
        ));
        // Use a fixed duration pump instead of pumpAndSettle because
        // CircularProgressIndicator animates indefinitely.
        // The duration must exceed flutter_animate delays to clear
        // pending timers.
        await tester.pump(const Duration(seconds: 2));

        expect(
          find.byType(CircularProgressIndicator),
          findsOneWidget,
        );
      });
    });

    group('navigation links', () {
      testWidgets('displays login link text', (tester) async {
        await tester.pumpWidget(buildRegisterScreen());
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Already have an account?'),
          findsOneWidget,
        );
        expect(find.textContaining('Log In'), findsOneWidget);
      });
    });
  });
}
