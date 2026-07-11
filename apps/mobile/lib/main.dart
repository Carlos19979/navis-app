import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:navis_mobile/app/app.dart';
import 'package:navis_mobile/app/router.dart';
import 'package:navis_mobile/core/config/env.dart';
import 'package:navis_mobile/core/config/settings_service.dart';
import 'package:navis_mobile/features/billing/billing.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  // Background messages are handled by the system notification tray.
  // No additional processing needed here.
}

void _handleNotificationTap(RemoteMessage message) {
  final documentId = message.data['document_id'];
  if (documentId != null) {
    // Schedule navigation after the current frame to ensure the
    // router is mounted and ready to handle the deep link.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        GoRouter.of(context).push('/documents/$documentId');
      }
    });
  }
}

// Initializes Firebase + push messaging. Firebase.initializeApp() is awaited
// (the notification providers, watched from the app root, require the [DEFAULT]
// app to exist). getInitialMessage() is intentionally NOT awaited: on devices
// without a push entitlement (free provisioning) or GoogleService-Info.plist,
// it waits for an APNs token that never arrives and would hang startup.
Future<void> _initPushNotifications() async {
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    unawaited(
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
          _handleNotificationTap(message);
        }
      }).catchError((_) {}),
    );
  } catch (_) {
    // Firebase not configured / push unavailable — notifications disabled.
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail fast on a production build wired to dev defaults (belt-and-suspenders
  // to the Makefile release-target guards).
  Env.assertProductionConfig();

  // Firebase must be ready before runApp; only the APNs-bound parts are deferred.
  await _initPushNotifications();

  final prefs = await SharedPreferences.getInstance();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  // Configure in-app purchases (no-op if no RevenueCat key is provided).
  await BillingService.instance.configure();

  if (Env.sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = Env.sentryDsn;
        options.tracesSampleRate = 0.2;
        options.environment = const String.fromEnvironment(
          'SENTRY_ENVIRONMENT',
          defaultValue: 'development',
        );
        options.release = const String.fromEnvironment(
          'APP_VERSION',
          defaultValue: '1.0.0',
        );
        options.beforeSend = (event, hint) {
          final request = event.request;
          if (request != null) {
            final headers = Map<String, String>.from(request.headers);
            headers.remove('Authorization');
            headers.remove('authorization');
            return event.copyWith(
              request: request.copyWith(headers: headers),
            );
          }
          return event;
        };
      },
      appRunner: () => runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const NavisApp(),
        ),
      ),
    );
  } else {
    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const NavisApp(),
      ),
    );
  }
}
