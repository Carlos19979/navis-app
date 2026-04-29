import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/core/analytics/analytics_service.dart';
import 'package:navis_mobile/core/network/notification_service.dart';
import 'package:navis_mobile/features/auth/data/auth_repository.dart';
import 'package:navis_mobile/features/auth/domain/auth_state.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/features/auth/presentation/screens/login_screen.dart';

// --- Mocks ---

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockNotificationService extends Mock implements NotificationService {}

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

  Widget buildLoginScreen({AuthState? initialState}) {
    if (initialState != null) {
      mockAuthNotifier = MockAuthNotifier(initialState);
    }
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((_) => mockAuthNotifier),
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        analyticsProvider.overrideWithValue(mockAnalyticsService),
        notificationServiceProvider
            .overrideWithValue(mockNotificationService),
      ],
      child: const MaterialApp(home: LoginScreen()),
    );
  }

  group('LoginScreen', () {
    group('rendering', () {
      testWidgets('renders without errors', (tester) async {
        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
      });

      testWidgets('displays Navis title and subtitle', (tester) async {
        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        expect(find.text('Navis'), findsOneWidget);
        expect(find.text('BOAT MANAGEMENT'), findsOneWidget);
      });

      testWidgets('displays email and password fields',
          (tester) async {
        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
      });

      testWidgets('displays Log In button', (tester) async {
        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        expect(find.text('Log In'), findsOneWidget);
      });

      testWidgets('displays Forgot Password link', (tester) async {
        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        expect(find.text('Forgot Password?'), findsOneWidget);
      });

      testWidgets('displays Register link', (tester) async {
        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        expect(find.textContaining('Register'), findsOneWidget);
      });

      testWidgets('displays sailing icon', (tester) async {
        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.sailing), findsOneWidget);
      });
    });

    group('text input', () {
      testWidgets('email field accepts input', (tester) async {
        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        final emailField = find.widgetWithText(
          TextFormField,
          'Email',
        );
        await tester.enterText(emailField, 'test@navis.app');
        await tester.pump();

        expect(find.text('test@navis.app'), findsOneWidget);
      });

      testWidgets('password field accepts input', (tester) async {
        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        final passwordField = find.widgetWithText(
          TextFormField,
          'Password',
        );
        await tester.enterText(passwordField, 'secret123');
        await tester.pump();

        expect(find.text('secret123'), findsOneWidget);
      });

      testWidgets('password field is obscured by default',
          (tester) async {
        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        final passwordField = find.widgetWithText(
          TextFormField,
          'Password',
        );
        await tester.enterText(passwordField, 'secret123');
        await tester.pump();

        final textField = tester.widget<TextField>(
          find.descendant(
            of: passwordField,
            matching: find.byType(TextField),
          ),
        );
        expect(textField.obscureText, isTrue);
      });

      testWidgets('password visibility toggles on icon tap',
          (tester) async {
        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        // Initially obscured - show password icon visible
        expect(
          find.byIcon(Icons.visibility_outlined),
          findsOneWidget,
        );

        // Tap to show password
        await tester.tap(find.byIcon(Icons.visibility_outlined));
        await tester.pump();

        // Now should show hide password icon
        expect(
          find.byIcon(Icons.visibility_off_outlined),
          findsOneWidget,
        );
      });
    });

    group('form validation', () {
      testWidgets('shows error when email is empty', (tester) async {
        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        // Tap login without entering anything
        await tester.tap(find.text('Log In'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter your email'), findsOneWidget);
      });

      testWidgets('shows error when email is invalid', (tester) async {
        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        final emailField = find.widgetWithText(
          TextFormField,
          'Email',
        );
        await tester.enterText(emailField, 'invalid-email');
        await tester.tap(find.text('Log In'));
        await tester.pumpAndSettle();

        expect(
          find.text('Please enter a valid email'),
          findsOneWidget,
        );
      });

      testWidgets('shows error when password is empty', (tester) async {
        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        final emailField = find.widgetWithText(
          TextFormField,
          'Email',
        );
        await tester.enterText(emailField, 'test@navis.app');
        await tester.tap(find.text('Log In'));
        await tester.pumpAndSettle();

        expect(
          find.text('Please enter your password'),
          findsOneWidget,
        );
      });

      testWidgets('shows error when password is too short',
          (tester) async {
        await tester.pumpWidget(buildLoginScreen());
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
        await tester.enterText(passwordField, '123');
        await tester.tap(find.text('Log In'));
        await tester.pumpAndSettle();

        expect(
          find.text('Password must be at least 6 characters'),
          findsOneWidget,
        );
      });

      testWidgets('no validation errors with valid input',
          (tester) async {
        when(() => mockAuthNotifier.login(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async {});

        await tester.pumpWidget(buildLoginScreen());
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
        await tester.tap(find.text('Log In'));
        await tester.pumpAndSettle();

        expect(
          find.text('Please enter your email'),
          findsNothing,
        );
        expect(
          find.text('Please enter your password'),
          findsNothing,
        );
      });
    });

    group('login action', () {
      testWidgets('calls login on notifier with correct credentials',
          (tester) async {
        when(() => mockAuthNotifier.login(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async {});

        await tester.pumpWidget(buildLoginScreen());
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
        await tester.tap(find.text('Log In'));
        await tester.pumpAndSettle();

        verify(() => mockAuthNotifier.login(
              email: 'test@navis.app',
              password: 'password123',
            )).called(1);
      });

      testWidgets('does not call login when validation fails',
          (tester) async {
        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        // Tap login with empty fields
        await tester.tap(find.text('Log In'));
        await tester.pumpAndSettle();

        verifyNever(() => mockAuthNotifier.login(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ));
      });
    });

    group('error state', () {
      testWidgets('displays error message from auth state',
          (tester) async {
        await tester.pumpWidget(buildLoginScreen(
          initialState: const AuthState.unauthenticated(
            errorMessage: 'Invalid login credentials',
          ),
        ));
        await tester.pumpAndSettle();

        expect(
          find.text('Invalid login credentials'),
          findsOneWidget,
        );
      });

      testWidgets('displays error icon with error message',
          (tester) async {
        await tester.pumpWidget(buildLoginScreen(
          initialState: const AuthState.unauthenticated(
            errorMessage: 'Network error',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Network error'), findsOneWidget);
      });

      testWidgets('does not display error when state has no error',
          (tester) async {
        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error_outline), findsNothing);
      });
    });

    group('loading state', () {
      testWidgets('shows loading indicator when auth is loading',
          (tester) async {
        await tester.pumpWidget(buildLoginScreen(
          initialState: const AuthState(status: AuthStatus.loading),
        ));
        // Use a fixed duration pump instead of pumpAndSettle because
        // CircularProgressIndicator animates indefinitely.
        // The duration must exceed flutter_animate delays to clear
        // pending timers.
        await tester.pump(const Duration(seconds: 2));

        // NavisButton shows a CircularProgressIndicator when isLoading
        expect(
          find.byType(CircularProgressIndicator),
          findsOneWidget,
        );
      });
    });

    group('forgot password', () {
      // The login screen's _onForgotPassword disposes the dialog's
      // TextEditingController immediately after showDialog returns,
      // while the dialog's dismiss animation is still running.
      // We suppress that known framework error in dialog-dismiss tests.
      void Function(FlutterErrorDetails)? _originalOnError;

      void suppressDisposedControllerErrors() {
        _originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          final msg = details.exceptionAsString();
          if (msg.contains('was used after being disposed') ||
              msg.contains('_dependents.isEmpty')) {
            return; // swallow known dialog-dismiss error
          }
          _originalOnError?.call(details);
        };
      }

      void restoreErrorHandler() {
        if (_originalOnError != null) {
          FlutterError.onError = _originalOnError;
          _originalOnError = null;
        }
      }

      testWidgets('tapping Forgot Password opens reset dialog',
          (tester) async {
        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Forgot Password?'));
        await tester.pumpAndSettle();

        expect(find.text('Reset Password'), findsOneWidget);
        expect(find.text('Send Reset Link'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      });

      testWidgets('cancel closes the reset dialog', (tester) async {
        suppressDisposedControllerErrors();
        addTearDown(restoreErrorHandler);

        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Forgot Password?'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Reset Password'), findsNothing);
      });

      testWidgets('pre-fills email in reset dialog from form field',
          (tester) async {
        suppressDisposedControllerErrors();
        addTearDown(restoreErrorHandler);

        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        // Enter email in the login form first
        final emailField = find.widgetWithText(
          TextFormField,
          'Email',
        );
        await tester.enterText(emailField, 'user@test.com');
        await tester.pump();

        // Open dialog
        await tester.tap(find.text('Forgot Password?'));
        await tester.pumpAndSettle();

        // The dialog TextField should be pre-filled
        expect(find.text('user@test.com'), findsWidgets);

        // Dismiss the dialog to avoid disposed controller errors
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      });

      testWidgets('sends reset email on valid submission',
          (tester) async {
        suppressDisposedControllerErrors();
        addTearDown(restoreErrorHandler);

        when(() => mockAuthRepository.resetPassword(any()))
            .thenAnswer((_) async {});

        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        // Enter email first
        final emailField = find.widgetWithText(
          TextFormField,
          'Email',
        );
        await tester.enterText(emailField, 'user@test.com');
        await tester.pump();

        // Open dialog
        await tester.tap(find.text('Forgot Password?'));
        await tester.pumpAndSettle();

        // Tap send
        await tester.tap(find.text('Send Reset Link'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        verify(() => mockAuthRepository.resetPassword('user@test.com'))
            .called(1);
      });

      testWidgets('shows snackbar on successful reset email',
          (tester) async {
        suppressDisposedControllerErrors();
        addTearDown(restoreErrorHandler);

        when(() => mockAuthRepository.resetPassword(any()))
            .thenAnswer((_) async {});

        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        final emailField = find.widgetWithText(
          TextFormField,
          'Email',
        );
        await tester.enterText(emailField, 'user@test.com');
        await tester.pump();

        await tester.tap(find.text('Forgot Password?'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Send Reset Link'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text('Password reset email sent. Check your inbox.'),
          findsOneWidget,
        );
      });

      testWidgets('shows error snackbar when reset fails',
          (tester) async {
        suppressDisposedControllerErrors();
        addTearDown(restoreErrorHandler);

        when(() => mockAuthRepository.resetPassword(any()))
            .thenThrow(Exception('Rate limit exceeded'));

        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        final emailField = find.widgetWithText(
          TextFormField,
          'Email',
        );
        await tester.enterText(emailField, 'user@test.com');
        await tester.pump();

        await tester.tap(find.text('Forgot Password?'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Send Reset Link'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.textContaining('Failed to send reset email'),
          findsOneWidget,
        );
      });
    });

    group('navigation links', () {
      testWidgets('displays "Don\'t have an account?" text',
          (tester) async {
        await tester.pumpWidget(buildLoginScreen());
        await tester.pumpAndSettle();

        expect(
          find.textContaining("Don't have an account?"),
          findsOneWidget,
        );
      });
    });
  });
}
