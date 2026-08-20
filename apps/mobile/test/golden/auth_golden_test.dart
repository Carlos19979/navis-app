@Tags(['golden'])
library;

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
import 'package:navis_mobile/features/auth/presentation/screens/register_screen.dart';

import 'golden_harness.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockNotifications extends Mock implements NotificationService {}

class _StubAuth extends StateNotifier<AuthState>
    with Mock
    implements AuthNotifier {
  _StubAuth() : super(const AuthState(status: AuthStatus.unauthenticated));
}

/// The first screen of the app, which is the one nobody had looked at.
///
/// It used to open with a 120 px circle carrying a glass fill, a border and a
/// 40-blur glow around the app icon — three treatments on an asset that is
/// already a logo — and every field wore a circular badge around its icon.
void main() {
  setUpAll(loadTestFonts);

  List<Override> overrides() => [
        authProvider.overrideWith((_) => _StubAuth()),
        authRepositoryProvider.overrideWithValue(_MockAuthRepository()),
        analyticsProvider.overrideWithValue(_MockAnalytics()),
        notificationServiceProvider.overrideWithValue(_MockNotifications()),
      ];

  for (final brightness in Brightness.values) {
    testWidgets('login — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        const LoginScreen(),
        brightness: brightness,
        settle: false,
        overrides: overrides(),
      );
      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile(goldenPath('login', brightness)),
      );
    });

    testWidgets('register — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        const RegisterScreen(),
        brightness: brightness,
        settle: false,
        overrides: overrides(),
      );
      await expectLater(
        find.byType(RegisterScreen),
        matchesGoldenFile(goldenPath('register', brightness)),
      );
    });
  }
}
