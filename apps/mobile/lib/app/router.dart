import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/network/supabase_client.dart';
import 'package:navis_mobile/features/auth/presentation/screens/check_email_screen.dart';
import 'package:navis_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:navis_mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:navis_mobile/features/boat/presentation/screens/boat_dashboard_screen.dart';
import 'package:navis_mobile/features/boat/presentation/screens/boat_detail_screen.dart';
import 'package:navis_mobile/features/boat/presentation/screens/boat_form_screen.dart';
import 'package:navis_mobile/features/boat/presentation/screens/document_detail_screen.dart';
import 'package:navis_mobile/features/charts/presentation/screens/chart_screen.dart';
import 'package:navis_mobile/features/documents/presentation/screens/document_form_screen.dart';
import 'package:navis_mobile/features/documents/presentation/screens/document_list_screen.dart';
import 'package:navis_mobile/features/maintenance/presentation/screens/maintenance_screen.dart';
import 'package:navis_mobile/features/cost/presentation/screens/cost_analytics_screen.dart';
import 'package:navis_mobile/features/readiness/presentation/screens/readiness_screen.dart';
import 'package:navis_mobile/features/shared/presentation/screens/bookings_screen.dart';
import 'package:navis_mobile/features/community/presentation/screens/community_screen.dart';
import 'package:navis_mobile/features/events/presentation/screens/event_detail_screen.dart';
import 'package:navis_mobile/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:navis_mobile/features/groups/presentation/screens/group_form_screen.dart';
import 'package:navis_mobile/features/regattas/presentation/screens/pre_trip_checklist_screen.dart';
import 'package:navis_mobile/features/regattas/presentation/screens/regatta_detail_screen.dart';
import 'package:navis_mobile/features/regattas/presentation/screens/schedule_regatta_screen.dart';
import 'package:navis_mobile/features/regattas/presentation/screens/start_event_regatta_screen.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/logbook_screen.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/trip_detail_screen.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/trip_edit_screen.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/trip_recording_screen.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/trip_stats_screen.dart';
import 'package:navis_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:navis_mobile/features/profile/presentation/screens/settings_screen.dart';
import 'package:navis_mobile/features/weather/presentation/screens/weather_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_bottom_nav.dart';

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    supabaseClient.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}

final _authNotifier = _AuthNotifier();

/// Global navigator key used by GoRouter.
/// Exposed for deep link navigation from push notification taps.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/boats',
    refreshListenable: _authNotifier,
    redirect: (context, state) {
      final session = supabaseClient.auth.currentSession;
      final isAuthenticated = session != null && !session.isExpired;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/check-email';

      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      if (isAuthenticated && isAuthRoute) {
        return '/boats';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/check-email',
        builder: (context, state) => const CheckEmailScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return NavisBottomNav(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/boats',
                builder: (context, state) => const BoatDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/charts',
                builder: (context, state) => const ChartScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/weather',
                builder: (context, state) => const WeatherScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                builder: (context, state) => const CommunityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/events/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EventDetailScreen(eventId: id);
        },
      ),
      GoRoute(
        path: '/groups/new',
        builder: (context, state) => const GroupFormScreen(),
      ),
      GoRoute(
        path: '/groups/:id/schedule',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ScheduleRegattaScreen(groupId: id);
        },
      ),
      GoRoute(
        path: '/events/:id/start-regatta',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return StartEventRegattaScreen(eventId: id);
        },
      ),
      GoRoute(
        path: '/groups/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return GroupDetailScreen(groupId: id);
        },
      ),
      GoRoute(
        path: '/regattas/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RegattaDetailScreen(regattaId: id);
        },
      ),
      GoRoute(
        path: '/trips/:id/checklist',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final groupId = state.uri.queryParameters['groupId'];
          return PreTripChecklistScreen(
            tripId: id,
            groupId: (groupId != null && groupId.isNotEmpty) ? groupId : null,
          );
        },
      ),
      GoRoute(
        path: '/boats/new',
        builder: (context, state) => const BoatFormScreen(boatId: 'new'),
      ),
      GoRoute(
        path: '/boats/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BoatDetailScreen(boatId: id);
        },
      ),
      GoRoute(
        path: '/boats/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BoatFormScreen(boatId: id);
        },
      ),
      GoRoute(
        path: '/boats/:id/documents',
        builder: (context, state) {
          final boatId = state.pathParameters['id']!;
          return DocumentListScreen(boatId: boatId);
        },
      ),
      GoRoute(
        path: '/boats/:id/maintenance',
        builder: (context, state) {
          final boatId = state.pathParameters['id']!;
          return MaintenanceScreen(boatId: boatId);
        },
      ),
      GoRoute(
        path: '/boats/:id/readiness',
        builder: (context, state) {
          final boatId = state.pathParameters['id']!;
          return ReadinessScreen(boatId: boatId);
        },
      ),
      GoRoute(
        path: '/boats/:id/costs',
        builder: (context, state) {
          final boatId = state.pathParameters['id']!;
          return CostAnalyticsScreen(boatId: boatId);
        },
      ),
      GoRoute(
        path: '/boats/:id/bookings',
        builder: (context, state) {
          final boatId = state.pathParameters['id']!;
          return BookingsScreen(boatId: boatId);
        },
      ),
      GoRoute(
        path: '/boats/:id/documents/new',
        builder: (context, state) {
          final boatId = state.pathParameters['id']!;
          return DocumentFormScreen(boatId: boatId);
        },
      ),
      GoRoute(
        path: '/boats/:id/trips',
        builder: (context, state) {
          final boatId = state.pathParameters['id']!;
          return LogbookScreen(boatId: boatId);
        },
      ),
      GoRoute(
        path: '/boats/:id/precheck',
        builder: (context, state) {
          final boatId = state.pathParameters['id']!;
          final port = state.uri.queryParameters['port'];
          return PreTripChecklistScreen(
            boatId: boatId,
            departurePort: (port != null && port.isNotEmpty) ? port : null,
          );
        },
      ),
      GoRoute(
        path: '/boats/:id/record',
        builder: (context, state) {
          final boatId = state.pathParameters['id']!;
          final tripId = state.uri.queryParameters['tripId'];
          final isRegatta = state.uri.queryParameters['regatta'] == 'true';
          final autoStart = state.uri.queryParameters['autostart'] == 'true';
          final port = state.uri.queryParameters['port'];
          return TripRecordingScreen(
            boatId: boatId,
            tripId: tripId,
            isRegatta: isRegatta,
            autoStart: autoStart,
            departurePort: (port != null && port.isNotEmpty) ? port : null,
          );
        },
      ),
      GoRoute(
        path: '/boats/:id/stats',
        builder: (context, state) {
          final boatId = state.pathParameters['id']!;
          return TripStatsScreen(boatId: boatId);
        },
      ),
      GoRoute(
        path: '/documents/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return DocumentDetailScreen(documentId: id);
        },
      ),
      GoRoute(
        path: '/documents/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final boatId = state.uri.queryParameters['boatId'] ?? '';
          final isRenew = state.uri.queryParameters['renew'] == 'true';
          return DocumentFormScreen(
            boatId: boatId,
            documentId: id,
            isRenew: isRenew,
          );
        },
      ),
      GoRoute(
        path: '/trips/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TripDetailScreen(tripId: id);
        },
      ),
      GoRoute(
        path: '/trips/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TripEditScreen(tripId: id);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
