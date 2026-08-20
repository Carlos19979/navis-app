import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/network/supabase_client.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/features/auth/presentation/screens/auth_link_screen.dart';
import 'package:navis_mobile/features/auth/presentation/screens/check_email_screen.dart';
import 'package:navis_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:navis_mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:navis_mobile/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:navis_mobile/features/boat/presentation/screens/today_screen.dart';
import 'package:navis_mobile/features/boat/presentation/screens/boat_form_screen.dart';
import 'package:navis_mobile/features/boat/presentation/screens/document_detail_screen.dart';
import 'package:navis_mobile/features/anchor/presentation/screens/anchor_alarm_screen.dart';
import 'package:navis_mobile/features/charts/presentation/screens/chart_screen.dart';
import 'package:navis_mobile/features/charts/presentation/screens/offline_charts_screen.dart';
import 'package:navis_mobile/features/documents/presentation/screens/document_form_screen.dart';
import 'package:navis_mobile/features/documents/presentation/screens/document_list_screen.dart';
import 'package:navis_mobile/features/maintenance/presentation/screens/expenses_screen.dart';
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
import 'package:navis_mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:navis_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:navis_mobile/features/weather/presentation/screens/weather_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_bottom_nav.dart';

/// Bridges Supabase auth events to GoRouter refreshes. Also flips the
/// [passwordRecoveryProvider] flag when a recovery deep link is opened so the
/// router can force the reset-password screen instead of treating the recovery
/// session as a normal login.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(this._ref) {
    _subscription = supabaseClient.auth.onAuthStateChange.listen((data) {
      if (data.event == supa.AuthChangeEvent.passwordRecovery) {
        _ref.read(passwordRecoveryProvider.notifier).begin();
      }
      notifyListeners();
    });
  }

  final Ref _ref;
  late final StreamSubscription<supa.AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Global navigator key used by GoRouter.
/// Exposed for deep link navigation from push notification taps.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthNotifier(ref);
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/boats',
    refreshListenable: authNotifier,
    // An auth email opens the app on `navis://login-callback?code=…`: a host
    // and a query, no path, so nothing here matches it and GoRouter falls
    // through to its default "Page Not Found". That is where password
    // recovery used to die — session already exchanged, user staring at an
    // error. AuthLinkScreen waits for the redirect below to take over.
    errorBuilder: (context, state) => AuthLinkScreen(uri: state.uri),
    redirect: (context, state) {
      final session = supabaseClient.auth.currentSession;
      final isAuthenticated = session != null && !session.isExpired;
      final isRecovering = ref.read(passwordRecoveryProvider);
      final location = state.matchedLocation;

      // A password-recovery session must land on the reset screen (never on
      // /boats) until the new password is set and the flag is cleared. Only
      // while there *is* a session: the flag outlives a restart now, and a
      // pending recovery with no session left would otherwise strand the user
      // on a screen whose only button cannot work.
      if (isRecovering && isAuthenticated) {
        return location == Routes.resetPassword ? null : Routes.resetPassword;
      }

      final isAuthRoute = location == Routes.login ||
          location == Routes.register ||
          location == Routes.checkEmail ||
          location == Routes.resetPassword;

      if (!isAuthenticated && !isAuthRoute) {
        return Routes.login;
      }

      if (isAuthenticated && isAuthRoute) {
        return Routes.today;
      }

      return null;
    },
    routes: [
      GoRoute(
          path: Routes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.checkEmail,
        builder: (context, state) => const CheckEmailScreen(),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return NavisBottomNav(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.today,
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.charts,
                builder: (context, state) => const ChartScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.weather,
                builder: (context, state) => const WeatherScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.community,
                builder: (context, state) => const CommunityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
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
        path: Routes.newGroup,
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
        path: Routes.newBoat,
        builder: (context, state) => const BoatFormScreen(boatId: 'new'),
      ),
      // Kept as a path even though the boat hub is gone: it is a notification
      // deep-link target (`notification_link.dart` maps `boat` here) and the
      // destination of nine `context.go('/boats')`-style calls. It now makes
      // that boat the active one and shows its Today.
      GoRoute(
        path: '/boats/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TodayScreen(boatId: id);
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
        path: '/boats/:id/expenses',
        builder: (context, state) {
          final boatId = state.pathParameters['id']!;
          return ExpensesScreen(boatId: boatId);
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
        path: '/boats/:id/anchor',
        builder: (context, state) {
          final boatId = state.pathParameters['id']!;
          return AnchorAlarmScreen(boatId: boatId);
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
      // Settings folded into the Profile tab: everything it held is inline
      // there now. The path stays as a redirect because it is a deep link and
      // an old push target.
      GoRoute(
        path: Routes.settings,
        redirect: (context, state) => Routes.profile,
      ),
      // Saved chart areas. Reachable from the chart's download sheet and from
      // Settings, so the storage they cost is never hidden from the user.
      GoRoute(
        path: Routes.offlineCharts,
        builder: (context, state) => const OfflineChartsScreen(),
      ),
      // The bell's destination: the history of everything the API delivered.
      GoRoute(
        path: Routes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
});
