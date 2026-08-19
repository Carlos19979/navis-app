import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:navis_mobile/core/config/settings_service.dart';
import 'package:navis_mobile/features/auth/data/auth_repository.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late SharedPreferences prefs;

  setUp(() async {
    mockAuthRepository = MockAuthRepository();
    // The pending recovery is read from storage, not injected: that *is* the
    // behaviour under test, since it has to survive the app being killed.
    SharedPreferences.setMockInitialValues({
      'auth_password_recovery_pending': true,
    });
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildResetPasswordScreen() {
    final router = GoRouter(
      initialLocation: '/reset-password',
      routes: [
        GoRoute(
          path: '/reset-password',
          builder: (context, state) => const ResetPasswordScreen(),
        ),
        GoRoute(
          path: '/boats',
          builder: (context, state) =>
              const Scaffold(body: Text('Boats screen')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
      ),
    );
  }

  Future<void> enterPasswords(
    WidgetTester tester, {
    required String password,
    required String confirm,
  }) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), password);
    await tester.enterText(fields.at(1), confirm);
    await tester.pump();
  }

  group('ResetPasswordScreen', () {
    testWidgets('renders new password fields and submit button',
        (tester) async {
      await tester.pumpWidget(buildResetPasswordScreen());
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.text('New password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Update password'), findsOneWidget);
    });

    testWidgets('does not call updatePassword when fields are empty',
        (tester) async {
      await tester.pumpWidget(buildResetPasswordScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update password'));
      await tester.pump();

      verifyNever(() => mockAuthRepository.updatePassword(any()));
    });

    testWidgets('does not call updatePassword when passwords do not match',
        (tester) async {
      await tester.pumpWidget(buildResetPasswordScreen());
      await tester.pumpAndSettle();

      await enterPasswords(
        tester,
        password: 'secret123',
        confirm: 'different1',
      );
      await tester.tap(find.text('Update password'));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
      verifyNever(() => mockAuthRepository.updatePassword(any()));
    });

    testWidgets('updates password and navigates on valid submission',
        (tester) async {
      when(() => mockAuthRepository.updatePassword(any()))
          .thenAnswer((_) async {});

      await tester.pumpWidget(buildResetPasswordScreen());
      await tester.pumpAndSettle();

      await enterPasswords(
        tester,
        password: 'secret123',
        confirm: 'secret123',
      );
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();

      verify(() => mockAuthRepository.updatePassword('secret123')).called(1);
      expect(find.text('Boats screen'), findsOneWidget);
    });

    testWidgets('shows error snackbar when update fails', (tester) async {
      when(() => mockAuthRepository.updatePassword(any()))
          .thenThrow(Exception('boom'));

      await tester.pumpWidget(buildResetPasswordScreen());
      await tester.pumpAndSettle();

      await enterPasswords(
        tester,
        password: 'secret123',
        confirm: 'secret123',
      );
      await tester.tap(find.text('Update password'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Could not update password. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
    });
  });
}
