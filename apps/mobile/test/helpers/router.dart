import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_theme.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

import 'test_helpers.dart';

/// Records every navigation a screen attempts, without needing stub pages for
/// each destination. Use with [buildRoutedTestApp].
class RouteSpy {
  final locations = <String>[];
  final extras = <Object?>[];

  /// The most recent recorded location, or null when nothing navigated.
  String? get last => locations.isEmpty ? null : locations.last;
}

/// Builds a routed test app hosting [child] at '/subject'.
///
/// Any navigation away from '/', '/subject' or '/__sink__' is intercepted by a
/// top-level redirect: the target location and its `extra` are recorded into
/// [spy], and the router lands on a neutral sink page instead. Assert on
/// `spy.last` / `spy.extras` rather than on stub page contents.
Widget buildRoutedTestApp(
  Widget child, {
  RouteSpy? spy,
  List<Override> overrides = const [],
}) {
  final router = GoRouter(
    initialLocation: '/subject',
    redirect: (context, state) {
      final location = state.uri.toString();
      if (location == '/' ||
          location == '/subject' ||
          location == '/__sink__') {
        return null;
      }
      spy?.locations.add(location);
      spy?.extras.add(state.extra);
      return '/__sink__';
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('__host__')),
        routes: [
          GoRoute(path: 'subject', builder: (_, __) => child),
          GoRoute(
            path: '__sink__',
            builder: (_, __) => const Scaffold(body: Text('__sink__')),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [...defaultTestOverrides, ...overrides],
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.dark,
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
