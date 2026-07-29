import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/boat/presentation/screens/boat_detail_screen.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/trip_recording_provider.dart';
import 'package:navis_mobile/features/readiness/presentation/providers/readiness_provider.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

import '../../helpers/helpers.dart';

/// Boat detail is the single place every boat section is reached from.
///
/// Two entry points are load-bearing here and are what these tests guard:
///
/// * **Anchor watch** — its only previous entry point was a chip in the boats
///   list that was removed. If this tile goes away, a paid (Plus+) feature
///   becomes unreachable from the app, with nothing failing at compile time.
/// * **Crew and permissions** — moved here from elsewhere, and owner-only:
///   nobody but the owner can grant a permission.
///
/// The sections live below the fold, hence the scrolling (or the tall
/// viewport used by the presence/absence tests, which need every tile
/// mounted at once for `findsNothing` to mean anything).

/// The screen only reads `isActive` off the recording state, so a seeded
/// StateNotifier is enough — no GPS involved.
class _FakeTripRecordingNotifier extends StateNotifier<TripRecordingState>
    with Mock
    implements TripRecordingNotifier {
  _FakeTripRecordingNotifier(super.state);
}

void main() {
  const boatId = 'boat-1';
  const anchorTile = 'Anchor watch';
  const crewTile = 'Crew and permissions';
  const statsTile = 'Trip Statistics';
  const costTile = 'Cost intelligence';
  const tripActiveWarning =
      'Stop the trip recording before starting an anchor watch.';
  const crewEmpty = "You haven't shared with anyone yet.";

  /// Everything the detail screen touches, so nothing reaches the network.
  List<Override> detailOverrides({
    PlanTier tier = PlanTier.pro,
    bool isOwner = true,
    TripRecordingState recording = TripRecordingState.initial,
  }) {
    return [
      ...planOverrides(tier: tier),
      boatProvider.overrideWith(
        (ref, id) async => makeBoat(id: id).copyWith(isOwner: isOwner),
      ),
      boatReadinessProvider.overrideWith((ref, id) async => makeReadiness()),
      boatMembersProvider.overrideWith((ref, id) async => const <BoatMember>[]),
      tripRecordingProvider.overrideWith(
        (ref) => _FakeTripRecordingNotifier(recording),
      ),
    ];
  }

  Future<RouteSpy> pumpDetail(
    WidgetTester tester, {
    PlanTier tier = PlanTier.pro,
    bool isOwner = true,
    TripRecordingState recording = TripRecordingState.initial,
  }) async {
    final spy = RouteSpy();
    await tester.pumpWidget(
      buildRoutedTestApp(
        const BoatDetailScreen(boatId: boatId),
        spy: spy,
        overrides: detailOverrides(
          tier: tier,
          isOwner: isOwner,
          recording: recording,
        ),
      ),
    );
    await pumpScreen(tester);
    return spy;
  }

  /// A viewport tall enough to mount every section at once, so asserting a
  /// tile is absent cannot be satisfied by it merely being off-screen.
  void setTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> scrollToTile(WidgetTester tester, String title) async {
    await tester.scrollUntilVisible(
      find.text(title),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  /// The card of the tile titled [title], to scope badge assertions to it.
  Finder tileCard(String title) => find.ancestor(
        of: find.text(title),
        matching: find.byType(NavisCard),
      );

  group('anchor watch entry point', () {
    testWidgets('Plus opens the anchor watch for this boat', (tester) async {
      setPhoneSize(tester);
      final spy = await pumpDetail(tester, tier: PlanTier.plus);

      await scrollToTile(tester, anchorTile);
      expect(find.text(anchorTile), findsOneWidget);
      // Entitled: no upsell pill on the tile.
      expect(
        find.descendant(of: tileCard(anchorTile), matching: find.text('PLUS')),
        findsNothing,
      );

      await tester.tap(find.text(anchorTile));
      await pumpScreen(tester);

      expectPaywall(shown: false);
      expect(spy.last, '/boats/$boatId/anchor');

      await drain(tester);
    });

    testWidgets('Free sees the PLUS pill and the paywall, and stays put',
        (tester) async {
      setPhoneSize(tester);
      final spy = await pumpDetail(tester, tier: PlanTier.free);

      await scrollToTile(tester, anchorTile);
      expect(
        find.descendant(of: tileCard(anchorTile), matching: find.text('PLUS')),
        findsOneWidget,
      );

      await tester.tap(find.text(anchorTile));
      await pumpScreen(tester);

      expectPaywall();
      expect(spy.locations, isEmpty);

      await drain(tester);
    });

    testWidgets('a trip being recorded blocks it and says why', (tester) async {
      setPhoneSize(tester);
      final spy = await pumpDetail(
        tester,
        tier: PlanTier.plus,
        recording: const TripRecordingState(
          status: RecordingStatus.recording,
          boatId: boatId,
        ),
      );

      await scrollToTile(tester, anchorTile);
      await tester.tap(find.text(anchorTile));
      await pumpScreen(tester);

      // Both drive the same GPS stream, so the watch must not start.
      expectSnackbar(tester, tripActiveWarning);
      expect(spy.locations, isEmpty);

      await drain(tester);
    });

    testWidgets('a paused trip blocks it before any paywall appears',
        (tester) async {
      setPhoneSize(tester);
      final spy = await pumpDetail(
        tester,
        tier: PlanTier.free,
        recording: const TripRecordingState(
          status: RecordingStatus.paused,
          boatId: boatId,
        ),
      );

      await scrollToTile(tester, anchorTile);
      await tester.tap(find.text(anchorTile));
      await pumpScreen(tester);

      expectSnackbar(tester, tripActiveWarning);
      expectPaywall(shown: false);
      expect(spy.locations, isEmpty);

      await drain(tester);
    });
  });

  group('crew management entry point', () {
    testWidgets('the owner gets it and it opens the crew sheet',
        (tester) async {
      setPhoneSize(tester);
      await pumpDetail(tester);

      await scrollToTile(tester, crewTile);
      await tester.tap(find.text(crewTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(crewEmpty), findsOneWidget);

      await drain(tester);
    });

    testWidgets('a member never sees it, permissions are the owner\'s to give',
        (tester) async {
      setTallViewport(tester);
      await pumpDetail(tester, isOwner: false);

      // The member branch, whole list on screen: the last tile proves it.
      expect(
        find.text(
          'This boat is shared with you. '
          'You have the permissions its owner granted.',
        ),
        findsOneWidget,
      );
      expect(find.text('Leave shared boat'), findsOneWidget);

      expect(find.text(crewTile), findsNothing);

      await drain(tester);
    });
  });

  group('every boat section is centralised here', () {
    testWidgets('owner sees anchor watch, crew, trip stats and costs together',
        (tester) async {
      setTallViewport(tester);
      await pumpDetail(tester);

      expect(find.text(anchorTile), findsOneWidget);
      expect(find.text(crewTile), findsOneWidget);
      expect(find.text(statsTile), findsOneWidget);
      expect(find.text(costTile), findsOneWidget);

      await drain(tester);
    });

    testWidgets('trip statistics still opens the stats page', (tester) async {
      setTallViewport(tester);
      final spy = await pumpDetail(tester);

      await tester.tap(find.text(statsTile));
      await pumpScreen(tester);

      expect(spy.last, '/boats/$boatId/stats');

      await drain(tester);
    });

    testWidgets('cost intelligence still opens the costs page', (tester) async {
      setTallViewport(tester);
      final spy = await pumpDetail(tester);

      await tester.tap(find.text(costTile));
      await pumpScreen(tester);

      expect(spy.last, '/boats/$boatId/costs');

      await drain(tester);
    });
  });
}
