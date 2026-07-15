// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/auth/domain/auth_state.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/features/auth/presentation/screens/check_email_screen.dart';

import '../../helpers/helpers.dart';

class _MockAuthNotifier extends StateNotifier<AuthState>
    with Mock
    implements AuthNotifier {
  _MockAuthNotifier(super.initial);
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  const email = 'sailor@navis.app';

  late _MockAuthNotifier mockNotifier;

  setUp(() {
    mockNotifier =
        _MockAuthNotifier(const AuthState.pendingEmailConfirmation(email));
    when(() => mockNotifier.resendConfirmationEmail()).thenAnswer((_) async {});
  });

  Widget buildSubject({RouteSpy? spy}) {
    return buildRoutedTestApp(
      const CheckEmailScreen(),
      spy: spy,
      overrides: [
        authProvider.overrideWith((_) => mockNotifier),
      ],
    );
  }

  group('CheckEmailScreen', () {
    testWidgets('renders title and body with the pending email interpolated',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('Check your email'), findsOneWidget);
      expect(find.textContaining(email), findsOneWidget);
      expect(find.text('Resend email'), findsOneWidget);
      expect(find.text('Back to login'), findsOneWidget);
    });

    testWidgets('resend success shows confirmation snackbar', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(find.text('Resend email'));
      await pumpScreen(tester);

      verify(() => mockNotifier.resendConfirmationEmail()).called(1);
      expectSnackbar(tester, 'Email sent');

      await drain(tester);
    });

    testWidgets('resend failure shows error snackbar', (tester) async {
      setPhoneSize(tester);
      when(() => mockNotifier.resendConfirmationEmail())
          .thenThrow(Exception('smtp down'));
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(find.text('Resend email'));
      await pumpScreen(tester);

      expectSnackbar(tester, 'Could not resend the email');

      await drain(tester);
    });

    testWidgets('back to login leaves pending state and navigates to /login',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(buildSubject(spy: spy));
      await pumpScreen(tester);

      await tester.tap(find.text('Back to login'));
      await pumpScreen(tester);

      verify(() => mockNotifier.backToLogin()).called(1);
      expect(spy.last, '/login');
    });
  });
}
