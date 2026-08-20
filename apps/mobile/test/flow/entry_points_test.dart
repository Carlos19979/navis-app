import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/boat/presentation/screens/today_screen.dart';
import 'package:navis_mobile/features/charts/presentation/screens/chart_screen.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/features/weather/presentation/screens/weather_screen.dart';

import '../helpers/helpers.dart';

/// Every action has to be reachable in every state where it is valid.
///
/// This is the test that would have caught the two flow bugs this redesign
/// introduced and a user found by asking:
///
///  * «and if I have no boat and want to join one?» — you could not. Joining
///    lived in the boat list's app bar, and moving it to a section that only
///    exists once you *have* a boat took the whole crew sign-up path with it.
///  * «and with one boat?» — adding a second was impossible for the same shape
///    of reason: «add a boat» moved into a sheet whose opener was gated on
///    having more than one.
///
/// Both were invisible to a screen review, because the screen was fine — the
/// state it was reviewed in was the wrong one. So this walks the states instead
/// of the screens, and asks only «is there a door», never «what does the door
/// look like». That is deliberate: the entry points have already moved twice,
/// and both times these assertions survived untouched while the layout tests
/// had to be rewritten.
void main() {
  setUpAll(() => registerFallbackValue(FakeRoute()));

  final one = [makeBoat()];
  final several = [
    makeBoat(),
    makeBoat(id: 'boat-2', name: 'Sea Runner'),
    makeBoat(id: 'boat-3', name: 'Marea'),
  ];

  Future<Widget> today({
    List<Boat> boats = const [],
    List<Boat> shared = const [],
    PlanTier tier = PlanTier.free,
    RouteSpy? spy,
  }) async {
    return buildRoutedTestApp(
      const TodayScreen(),
      spy: spy,
      overrides: [
        ...await todayOverrides(boats: boats, shared: shared),
        ...planOverrides(tier: tier),
      ],
    );
  }

  /// Whether [label] can be reached from Today: on the page itself, or one tap
  /// into the boats sheet. *Where* it is does not matter — only that a user in
  /// this state can get to it.
  Future<bool> reachable(WidgetTester tester, String label) async {
    if (find.text(label).evaluate().isNotEmpty) return true;

    final chevron = find.byIcon(Icons.expand_more_rounded);
    if (chevron.evaluate().isNotEmpty) {
      await tester.tap(chevron.first);
      await pumpFrames(tester, frames: 6);
      if (find.text(label).evaluate().isNotEmpty) return true;
      await tester.tapAt(const Offset(200, 40));
      await pumpFrames(tester, frames: 4);
    }

    await scrollAndCollectText(tester, find.byKey(todayScrollKey));
    return find.text(label).evaluate().isNotEmpty;
  }

  group('adding a boat', () {
    for (final (name, boats, shared) in [
      ('with none at all', const <Boat>[], const <Boat>[]),
      ('with one of your own', null, const <Boat>[]),
      ('with several', null, const <Boat>[]),
      ('with only a shared one', const <Boat>[], null),
    ]) {
      testWidgets('is reachable $name', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(
          await today(
            boats: switch (name) {
              'with one of your own' => one,
              'with several' => several,
              _ => boats ?? const [],
            },
            shared: shared ?? [makeBoat(id: 's1', name: 'Crewed')],
            tier: PlanTier.pro,
          ),
        );
        await pumpFrames(tester, frames: 8);

        expect(
          await reachable(tester, 'Add boat'),
          isTrue,
          reason: 'no way to add a boat $name',
        );
      });
    }
  });

  group('joining a boat', () {
    for (final name in ['with none at all', 'with one', 'with several']) {
      testWidgets('is reachable $name', (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(
          await today(
            boats: switch (name) {
              'with one' => one,
              'with several' => several,
              _ => const [],
            },
            tier: PlanTier.pro,
          ),
        );
        await pumpFrames(tester, frames: 8);

        // The one that was actually broken: a crew member invited to someone
        // else's boat has no boat of their own to add.
        expect(
          await reachable(tester, 'Join a boat'),
          isTrue,
          reason: 'no way to join a boat $name',
        );
      });
    }
  });

  group('the paid entry points are marked, never missing', () {
    for (final tier in PlanTier.values) {
      testWidgets('cost intelligence is on the page on ${tier.name}',
          (tester) async {
        setPhoneSize(tester);
        await tester.pumpWidget(await today(boats: one, tier: tier));
        await pumpFrames(tester, frames: 8);

        // A gated row is present and marked, not absent. Hiding it is how a
        // paid feature stops existing for the people who might pay for it.
        final labels = await scrollAndCollectText(
          tester,
          find.byKey(todayScrollKey),
        );
        expect(labels, contains('Cost intelligence'));
        if (tier != PlanTier.pro) {
          expect(labels, contains('PRO'));
        }
      });
    }
  });

  group('a crew member', () {
    testWidgets('can still leave the boat they were invited to',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        await today(shared: [makeBoat(id: 's1', isOwner: false)]),
      );
      await pumpFrames(tester, frames: 8);

      final labels = await scrollAndCollectText(
        tester,
        find.byKey(todayScrollKey),
      );
      expect(labels, contains('Leave shared boat'));
      // And is not shown the owner's tools.
      expect(labels, isNot(contains('Share boat')));
    });
  });

  /// The matrix, extended past Today.
  ///
  /// The audit's other finding was that the two tabs a sailor opens *before*
  /// leaving — the forecast and the chart — had no way to leave from. Reachable
  /// «from Today» was never the requirement; reachable from where the user is
  /// standing was.
  group('sailing is reachable from the tab the user is on', () {
    testWidgets('from the forecast', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildTestApp(
          const WeatherScreen(),
          overrides: [
            weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
            boatsProvider.overrideWith(() => FakeBoatsNotifier([makeBoat()])),
          ],
        ),
      );
      await pumpFrames(tester, frames: 8);
      addTearDown(() => drain(tester));

      expect(find.text('Start trip'), findsOneWidget);
    });

    testWidgets('from the chart', (tester) async {
      setPhoneSize(tester);
      installTileNoiseFilter();
      installFakeGeo();
      await tester.pumpWidget(
        buildTestApp(
          const ChartScreen(),
          overrides: [
            overridePorts(),
            boatsProvider.overrideWith(() => FakeBoatsNotifier([makeBoat()])),
          ],
        ),
      );
      await pumpFrames(tester, frames: 8);
      addTearDown(() => drain(tester));

      expect(find.text('Start trip'), findsOneWidget);
      expect(find.text('Anchor'), findsOneWidget);
    });

    testWidgets('and neither tab invents a boat it does not have',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildTestApp(
          const WeatherScreen(),
          overrides: [
            weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
          ],
        ),
      );
      await pumpFrames(tester, frames: 8);
      addTearDown(() => drain(tester));

      expect(find.text('Start trip'), findsNothing);
    });
  });
}
