import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:navis_mobile/app/app.dart';
import 'package:navis_mobile/app/router.dart';
import 'package:navis_mobile/core/config/env.dart';

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    final initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  } catch (_) {
    // Firebase not configured — push notifications disabled
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

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
            final headers =
                Map<String, String>.from(request.headers);
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
        const ProviderScope(
          child: NavisApp(),
        ),
      ),
    );
  } else {
    runApp(
      const ProviderScope(
        child: NavisApp(),
      ),
    );
  }
}
