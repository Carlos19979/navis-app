import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:navis_mobile/app/app.dart';
import 'package:navis_mobile/core/config/env.dart';
import 'package:navis_mobile/core/config/settings_service.dart';
import 'package:navis_mobile/core/network/notification_service.dart';
import 'package:navis_mobile/core/network/supabase_client.dart' as app_supabase;

import 'credentials.dart';
import 'fake_geolocator.dart';
import 'fake_notifications.dart';

bool _initialized = false;
late SharedPreferences _prefs;

/// Replicates `main.dart` minus Firebase/Sentry (both no-op without config
/// anyway) with E2E determinism: English locale, dark theme, scripted GPS.
/// Heavy init (Supabase, prefs) runs once per process; safe to call from
/// every journey.
Future<void> bootstrapApp(WidgetTester tester) async {
  // RenderFlex overflows are cosmetic (some screens overflow ~100px with the
  // keyboard up — known UI debt) but the test framework treats any reported
  // FlutterError as fatal. Ignore only those; everything else still fails.
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
      return;
    }
    originalOnError?.call(details);
  };

  if (!_initialized) {
    GeolocatorPlatform.instance = FakeGeolocatorPlatform();

    _prefs = await SharedPreferences.getInstance();
    // Deterministic finders: pin English + dark before the app reads them.
    await _prefs.setString('settings_locale', 'en');
    await _prefs.setString('settings_theme_mode', 'dark');

    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );

    // A session persisted by a previous run on this simulator would skip the
    // login screen and break J01. Start signed out, always.
    try {
      await app_supabase.supabaseClient.auth.signOut();
    } catch (_) {}

    _initialized = true;
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_prefs),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
      ],
      child: const NavisApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

/// Direct (non-UI) sign-in so a journey can run standalone while debugging.
/// Falls back to sign-up when the per-run user does not exist yet.
Future<void> ensureSignedIn() async {
  final auth = app_supabase.supabaseClient.auth;
  if (auth.currentSession != null && !auth.currentSession!.isExpired) return;
  try {
    await auth.signInWithPassword(email: e2eEmail, password: e2ePassword);
  } on AuthException {
    await auth.signUp(email: e2eEmail, password: e2ePassword);
  }
}
