// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/screens/today_screen.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/readiness/data/readiness_repository.dart';

import '../../helpers/helpers.dart';

/// Today is the home screen, and it absorbed two screens that used to be
/// separate: the boat list and the twelve-row boat hub. This file carries the
/// behaviour tests from both, because the behaviour did not go away — only the
/// intermediate screen did.
class MockBoatShareRepository extends Mock implements BoatShareRepository {}

void main() {
  setUpAll(() => registerFallbackValue(FakeRoute()));

  // makeBoat already homeports in Palma; named here only where a test
  // asserts on it.
  final oneBoat = [makeBoat()];
  final twoBoats = [
    makeBoat(),
    makeBoat(
      id: 'boat-2',
      name: 'Sea Runner',
      type: 'motorboat',
      registration: 'ES-BCN-7-5678',
    ),
  ];

  Future<Widget> subject({
    List<Boat> boats = const [],
    List<Boat> shared = const [],
    bool useError = false,
    bool neverCompletes = false,
    bool isPro = false,
    PlanTier? tier,
    Readiness? readiness,
    DocumentSummary summary = const DocumentSummary(),
    Map<String, Object> prefs = const {},
    FakeBoatsNotifier? notifier,
    RouteSpy? spy,
    List<Override> extra = const [],
  }) async {
    return buildRoutedTestApp(
      const TodayScreen(),
      spy: spy,
      overrides: [
        ...await todayOverrides(
          boats: boats,
          shared: shared,
          notifier: useError
              ? ErrorBoatsNotifier.new
              : neverCompletes
                  ? NeverCompleteBoatsNotifier.new
                  : (notifier == null ? null : () => notifier),
          readiness: readiness,
          summary: summary,
          prefs: prefs,
        ),
        ...planOverrides(pro: isPro, tier: tier),
        ...extra,
      ],
    );
  }

  group('which boat Today is about', () {
    testWidgets('with one boat it is that boat, and no switcher is offered',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(await subject(boats: oneBoat));
      await pumpFrames(tester, frames: 8);

      expect(find.text('Luna Azul'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
    });

    testWidgets('with several boats the name opens a picker', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(await subject(boats: twoBoats));
      await pumpFrames(tester, frames: 8);

      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
      await tester.tap(find.text('Luna Azul').first);
      await pumpFrames(tester, frames: 8);

      expect(find.text('CHANGE BOAT'), findsOneWidget);
      expect(find.text('Sea Runner'), findsWidgets);
    });

    testWidgets('the stored choice wins over the first boat', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        await subject(boats: twoBoats, prefs: {'active_boat_id': 'boat-2'}),
      );
      await pumpFrames(tester, frames: 8);

      // The header is the active boat; the other one appears further down under
      // "My Boats", so scope the assertion to the top of the page.
      expect(find.text('ES-BCN-7-5678'), findsWidgets);
    });

    testWidgets('a stored id that no longer exists falls back to the first',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        await subject(boats: oneBoat, prefs: {'active_boat_id': 'gone'}),
      );
      await pumpFrames(tester, frames: 8);

      expect(find.text('Luna Azul'), findsOneWidget);
    });

    testWidgets('a shared boat is enough to have a home', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        await subject(shared: [makeBoat(id: 's1', name: 'Crewed')]),
      );
      await pumpFrames(tester, frames: 8);

      expect(find.text('Crewed'), findsOneWidget);
    });
  });

  group('with more than one boat', () {
    final threeBoats = [
      makeBoat(),
      makeBoat(id: 'boat-2', name: 'Sea Runner', type: 'motorboat'),
      makeBoat(id: 'boat-3', name: 'Marea'),
    ];

    testWidgets('the others are listed with what needs doing on them',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        await subject(
          boats: threeBoats,
          // Every boat resolves through the same family override, so the two
          // that are not active carry an alert too — which is the point of the
          // section: an owner of three boats used to lose this when the list of
          // cards went away.
          summary: const DocumentSummary(total: 2, expired: 1, ok: 1),
        ),
      );
      await pumpFrames(tester, frames: 8);

      final labels = await scrollAndCollectText(
        tester,
        find.byKey(todayScrollKey),
      );
      expect(labels, containsAll(['Sea Runner', 'Marea']));
      expect(
        labels.where((t) => t.contains('alert')),
        isNotEmpty,
        reason: 'an other-boat row must say when that boat needs attention',
      );
    });

    testWidgets('the switcher carries a dot when another boat needs attention',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        await subject(
          boats: threeBoats,
          summary: const DocumentSummary(total: 2, expired: 1, ok: 1),
        ),
      );
      await pumpFrames(tester, frames: 8);

      // The "My boats" section is next to last on the page, so without this the
      // only signal that another boat has an expired document is a long scroll
      // away.
      final badge = tester.widget<Badge>(find.byType(Badge).first);
      expect(badge.isLabelVisible, isTrue);
    });

    testWidgets('and no dot when the others are fine', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        await subject(
          boats: threeBoats,
          summary: const DocumentSummary(total: 2, ok: 2),
        ),
      );
      await pumpFrames(tester, frames: 8);

      final badge = tester.widget<Badge>(find.byType(Badge).first);
      expect(badge.isLabelVisible, isFalse);
    });

    testWidgets('tapping another boat scrolls back to the top', (tester) async {
      // A real phone viewport, not `setPhoneSize`'s 1080x1920: at that height
      // the whole page fits and there is no scroll offset to observe.
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await subject(boats: threeBoats));
      await pumpFrames(tester, frames: 8);

      final scrollable = find.byKey(todayScrollKey);
      final controller = tester.widget<ListView>(scrollable).controller!;
      await tester.drag(scrollable, const Offset(0, -1200));
      await pumpFrames(tester, frames: 4);
      expect(
        controller.offset,
        greaterThan(0),
        reason: 'the other-boat rows sit below the fold',
      );

      await scrollUntilVisible(tester, find.text('Sea Runner'), todayScrollKey);
      await tester.tap(find.text('Sea Runner'));
      await pumpFrames(tester, frames: 8);

      // Otherwise the new boat's Today opens at the bottom, on the very list
      // that was just tapped, and it reads as if nothing happened.
      expect(controller.offset, 0);
    });

    testWidgets('the picker scrolls, so a long crew list cannot overflow it',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        await subject(
          boats: threeBoats,
          shared: [
            for (var i = 0; i < 6; i++)
              makeBoat(id: 'shared-$i', name: 'Compartido $i'),
          ],
        ),
      );
      await pumpFrames(tester, frames: 8);

      await tester.tap(find.text('Luna Azul').first);
      await pumpFrames(tester, frames: 8);

      expect(find.text('CHANGE BOAT'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the first screenful answers "can I go out?"', () {
    testWidgets('the readiness score and its status lead the page',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        await subject(
          boats: oneBoat,
          readiness:
              fakeReadiness(score: 72, status: ReadinessStatus.attention),
        ),
      );
      await pumpFrames(tester, frames: 8);

      expect(find.text('72'), findsOneWidget);
      expect(find.text('Needs attention'), findsOneWidget);
    });

    testWidgets('tapping the score opens the full readiness breakdown',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(await subject(boats: oneBoat, spy: spy));
      await pumpFrames(tester, frames: 8);

      await tester.tap(find.text('Ready to sail'));
      await pumpFrames(tester, frames: 8);

      expect(spy.locations, contains('/boats/boat-1/readiness'));
    });

    testWidgets('coming-up lists what needs doing, worst first',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        await subject(
          boats: oneBoat,
          readiness: fakeReadiness(
            score: 40,
            status: ReadinessStatus.notReady,
            attention: const [
              ReadinessItem(
                category: 'documents',
                ref: 'insurance_rc',
                status: ReadinessStatus.notReady,
                days: -3,
              ),
            ],
          ),
        ),
      );
      await pumpFrames(tester, frames: 8);

      expect(find.text('COMING UP'), findsOneWidget);
      expect(find.text('Insurance'), findsOneWidget);
    });

    testWidgets(
        'with nothing pending it says so instead of showing an empty '
        'heading', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(await subject(boats: oneBoat));
      await pumpFrames(tester, frames: 8);

      expect(find.text('Nothing needs doing'), findsOneWidget);
    });

    testWidgets('cast off is one tap from home', (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(await subject(boats: oneBoat, spy: spy));
      await pumpFrames(tester, frames: 8);

      await tester.tap(find.text('Start Trip'));
      await pumpFrames(tester, frames: 8);

      expect(spy.locations, contains('/boats/boat-1/precheck'));
    });
  });

  group('anchor watch entry point', () {
    testWidgets('Plus opens the anchor watch for this boat', (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        await subject(boats: oneBoat, tier: PlanTier.plus, spy: spy),
      );
      await pumpFrames(tester, frames: 8);

      await tester.tap(find.text('Anchor'));
      await pumpFrames(tester, frames: 8);

      expect(spy.locations, contains('/boats/boat-1/anchor'));
    });

    testWidgets('Free sees the PLUS pill and the paywall, and stays put',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(await subject(boats: oneBoat, spy: spy));
      await pumpFrames(tester, frames: 8);

      expect(find.text('PLUS'), findsWidgets);
      await tester.tap(find.text('Anchor'));
      await pumpFrames(tester, frames: 8);

      expect(spy.locations, isNot(contains('/boats/boat-1/anchor')));
    });
  });

  group('every boat destination is reachable from here', () {
    testWidgets('the sections that replaced the hub are all present',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(await subject(boats: oneBoat, isPro: true));
      await pumpFrames(tester, frames: 8);

      final labels = await scrollAndCollectText(
        tester,
        find.byKey(todayScrollKey),
      );
      expect(
        labels,
        containsAll([
          'Documents',
          'Logbook',
          'Trip Statistics',
          'Maintenance & expenses',
          'Cost intelligence',
          'Bookings',
          'Crew and permissions',
          'Share boat',
          'Edit Boat',
        ]),
      );
    });

    testWidgets('documents carries the summary and opens the list',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        await subject(
          boats: oneBoat,
          spy: spy,
          summary: const DocumentSummary(total: 3, expired: 1, ok: 2),
        ),
      );
      await pumpFrames(tester, frames: 8);

      await tester.tap(find.text('Documents'));
      await pumpFrames(tester, frames: 8);

      expect(spy.locations, contains('/boats/boat-1/documents'));
    });

    testWidgets('trip statistics still opens the stats page', (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(await subject(boats: oneBoat, spy: spy));
      await pumpFrames(tester, frames: 8);

      await tester.tap(find.text('Trip Statistics'));
      await pumpFrames(tester, frames: 8);

      expect(spy.locations, contains('/boats/boat-1/stats'));
    });

    testWidgets('cost intelligence opens the costs page on Pro',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        await subject(boats: oneBoat, isPro: true, spy: spy),
      );
      await pumpFrames(tester, frames: 8);

      await tester.tap(find.text('Cost intelligence'));
      await pumpFrames(tester, frames: 8);

      expect(spy.locations, contains('/boats/boat-1/costs'));
    });

    testWidgets('the boat details are readable without opening the edit form',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(await subject(boats: oneBoat));
      await pumpFrames(tester, frames: 8);

      final labels = await scrollAndCollectText(
        tester,
        find.byKey(todayScrollKey),
      );
      expect(labels, contains('ES-MAL-3-1234'));
      expect(labels, contains('Palma de Mallorca'));
    });
  });

  group('a crew member sees a different page', () {
    testWidgets('no owner-only rows, and a way out of the boat',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        await subject(shared: [makeBoat(id: 's1', isOwner: false)]),
      );
      await pumpFrames(tester, frames: 8);

      final labels = await scrollAndCollectText(
        tester,
        find.byKey(todayScrollKey),
      );
      expect(labels, isNot(contains('Crew and permissions')));
      expect(labels, isNot(contains('Share boat')));
      expect(labels, contains('Leave shared boat'));
    });
  });

  group('adding a boat', () {
    testWidgets('under the plan limit it opens the form', (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      // Pro, because Free allows exactly one boat — with one boat an owner is
      // already at the limit, not under it.
      await tester.pumpWidget(
        await subject(boats: oneBoat, isPro: true, spy: spy),
      );
      await pumpFrames(tester, frames: 8);

      await scrollUntilVisible(tester, find.text('Add Boat'), todayScrollKey);
      await tester.tap(find.text('Add Boat'));
      await pumpFrames(tester, frames: 8);

      expect(spy.locations, contains('/boats/new'));
    });

    testWidgets('at the Free limit it offers the paywall instead',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(await subject(boats: oneBoat, spy: spy));
      await pumpFrames(tester, frames: 8);

      await scrollUntilVisible(tester, find.text('Add Boat'), todayScrollKey);
      await tester.tap(find.text('Add Boat'));
      await pumpFrames(tester, frames: 8);

      expect(spy.locations, isNot(contains('/boats/new')));
    });
  });

  group('the states around the data', () {
    testWidgets('no boats at all gets the value proposition and a CTA',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(await subject());
      await pumpFrames(tester, frames: 8);

      expect(find.textContaining('No boats yet'), findsOneWidget);
      expect(find.text('Add Boat'), findsOneWidget);
    });

    testWidgets('a failed load explains itself and offers a retry',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(await subject(useError: true));
      await pumpFrames(tester, frames: 8);

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('while loading it shows a skeleton, not an empty page',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(await subject(neverCompletes: true));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('No boats yet'), findsNothing);
      await drain(tester);
    });
  });

  group('deleting the boat', () {
    testWidgets('asks first, names the boat, and only then deletes',
        (tester) async {
      setPhoneSize(tester);
      final notifier = FakeBoatsNotifier(oneBoat);
      await tester.pumpWidget(
        await subject(boats: oneBoat, notifier: notifier),
      );
      await pumpFrames(tester, frames: 8);

      await scrollUntilVisible(
        tester,
        find.text('Delete Boat'),
        todayScrollKey,
      );
      await tester.tap(find.text('Delete Boat').first);
      await pumpFrames(tester, frames: 8);

      expect(find.textContaining('Luna Azul'), findsWidgets);
      expect(notifier.deleted, isEmpty);

      await tester.tap(find.text('Delete').last);
      await pumpFrames(tester, frames: 8);

      expect(notifier.deleted, ['boat-1']);
    });

    testWidgets('cancelling leaves the boat alone', (tester) async {
      setPhoneSize(tester);
      final notifier = FakeBoatsNotifier(oneBoat);
      await tester.pumpWidget(
        await subject(boats: oneBoat, notifier: notifier),
      );
      await pumpFrames(tester, frames: 8);

      await scrollUntilVisible(
        tester,
        find.text('Delete Boat'),
        todayScrollKey,
      );
      await tester.tap(find.text('Delete Boat').first);
      await pumpFrames(tester, frames: 8);
      await tester.tap(find.text('Cancel'));
      await pumpFrames(tester, frames: 8);

      expect(notifier.deleted, isEmpty);
    });
  });
}
