import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/features/community/presentation/screens/community_screen.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/trip_stats_screen.dart';

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

  testWidgets('an empty regatta feed has the clubs right below it',
      (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(
      buildTestApp(
        const CommunityScreen(),
        overrides: [
          eventsProvider.overrideWith((ref) async => const []),
          myGroupsProvider.overrideWith((ref) async => const <Group>[]),
          discoverGroupsProvider.overrideWith((ref) async => const <Group>[]),
          ...planOverrides(),
        ],
      ),
    );
    final labels = await scrollAndCollectText(
      tester,
      find.byKey(communityScrollKey),
    );

    // This one stopped needing an exit. The old feed was its own tab, so an
    // empty one had to send the user to «Explore clubs»; in a single feed the
    // clubs are the next thing down the page, which is better than a button
    // that navigates to what you are already looking at.
    expect(
      labels.any((t) => t.contains('Regattas are scheduled by a club')),
      isTrue,
    );
    expect(labels, containsAll(['MY CLUBS', 'DISCOVER CLUBS']));
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
