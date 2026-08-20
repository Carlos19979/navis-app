import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/features/events/presentation/screens/events_screen.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/trip_stats_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';

import '../helpers/helpers.dart';

/// An empty screen has to offer the thing that fills it.
///
/// Three of the app's twelve empty states offered nothing at all: a heading, an
/// icon, and no way forward. It is the same failure as «join a boat» being
/// unreachable with no boats — a state the design never got looked at in.
///
/// The interesting part is that the right exit is different every time, so
/// «always add a CTA» is not the rule. A regatta cannot be created from the
/// regatta feed, and an empty *period* of expenses is not an empty ledger.
void main() {
  setUpAll(() => registerFallbackValue(FakeRoute()));

  testWidgets('an empty regatta feed points at the clubs', (tester) async {
    setPhoneSize(tester);
    final spy = RouteSpy();
    await tester.pumpWidget(
      buildRoutedTestApp(
        const EventsScreen(),
        spy: spy,
        overrides: [eventsProvider.overrideWith((ref) async => const [])],
      ),
    );
    await pumpFrames(tester, frames: 6);

    // Not «create a regatta»: a regatta is scheduled from a club, so this
    // screen cannot offer one. The clubs are the only honest way out.
    final state = tester.widget<NavisEmptyState>(find.byType(NavisEmptyState));
    expect(state.onAction, isNotNull);
    await tester.tap(find.text('Explore clubs'));
    await pumpFrames(tester, frames: 4);
    expect(spy.locations, contains('/community'));
  });

  testWidgets('statistics with no trips offers recording one', (tester) async {
    setPhoneSize(tester);
    final spy = RouteSpy();
    await tester.pumpWidget(
      buildRoutedTestApp(
        const TripStatsScreen(boatId: 'boat-1'),
        spy: spy,
        overrides: [
          allBoatTripsProvider.overrideWith((ref, id) async => const []),
        ],
      ),
    );
    await pumpFrames(tester, frames: 6);

    await tester.tap(find.text('Record Trip'));
    await pumpFrames(tester, frames: 4);
    expect(spy.locations, contains('/boats/boat-1/precheck'));
  });
}
