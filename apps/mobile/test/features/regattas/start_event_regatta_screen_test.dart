import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/events/domain/entities/event.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/features/regattas/data/repositories/regatta_repository.dart';
import 'package:navis_mobile/features/regattas/presentation/providers/regatta_provider.dart';
import 'package:navis_mobile/features/regattas/presentation/screens/start_event_regatta_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';

import '../../helpers/helpers.dart';

class _MockRegattaRepository extends Mock implements RegattaRepository {}

class _FakeBoatsNotifier extends AsyncNotifier<List<Boat>>
    implements BoatsNotifier {
  _FakeBoatsNotifier(this._boats);
  final List<Boat> _boats;

  @override
  Future<List<Boat>> build() async => _boats;
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<Boat> createBoat(Boat boat) async => boat;
  @override
  Future<void> updateBoat(Boat boat) async {}
  @override
  Future<void> deleteBoat(String id) async {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  const eventId = 'e1';

  late _MockRegattaRepository mockRepo;

  setUp(() {
    mockRepo = _MockRegattaRepository();
  });

  Widget buildSubject({
    RouteSpy? spy,
    List<Group> groups = const [],
    List<Boat> boats = const [],
    Future<Event> Function()? fetchEvent,
  }) {
    return buildRoutedTestApp(
      const StartEventRegattaScreen(eventId: eventId),
      spy: spy,
      overrides: [
        regattaRepositoryProvider.overrideWithValue(mockRepo),
        eventProvider.overrideWith(
          (ref, id) => fetchEvent != null
              ? fetchEvent()
              : Future.value(makeEvent(id: eventId)),
        ),
        myGroupsProvider.overrideWith((ref) async => groups),
        boatsProvider.overrideWith(() => _FakeBoatsNotifier(boats)),
      ],
    );
  }

  Finder joinButton() => find.widgetWithText(NavisButton, 'Join with my group');

  void stubSchedule({String regattaId = 'r9'}) {
    when(() => mockRepo.schedule(
          groupId: any(named: 'groupId'),
          boatId: any(named: 'boatId'),
          departurePort: any(named: 'departurePort'),
          title: any(named: 'title'),
          scheduledAt: any(named: 'scheduledAt'),
        )).thenAnswer((_) async => makeRegatta(id: regattaId));
  }

  group('StartEventRegattaScreen pickers', () {
    testWidgets('shows the event name and only owned groups', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          groups: [
            makeGroup(),
            makeGroup(id: 'g2', name: 'Other Club', myRole: 'member'),
          ],
          boats: [makeBoat()],
        ),
      );
      await pumpScreen(tester);

      expect(find.text('Copa del Rey'), findsOneWidget);
      expect(find.text('Palma Sailing Club'), findsOneWidget);
      expect(find.text('Other Club'), findsNothing);
    });

    testWidgets('no owned groups shows the create-group CTA', (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildSubject(
          spy: spy,
          groups: [makeGroup(id: 'g2', name: 'Other Club', myRole: 'member')],
          boats: [makeBoat()],
        ),
      );
      await pumpScreen(tester);

      expect(
        find.text('Create a group first to join with your team.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Create group'));
      await pumpScreen(tester);

      expect(spy.last, '/groups/new');
    });

    testWidgets('no boats shows the add-boat CTA', (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildSubject(spy: spy, groups: [makeGroup()]),
      );
      await pumpScreen(tester);

      expect(find.text('Add a boat first.'), findsOneWidget);

      await tester.tap(find.text('Add Boat'));
      await pumpScreen(tester);

      expect(spy.last, '/boats/new');
    });
  });

  group('StartEventRegattaScreen validation', () {
    testWidgets('joining without a group shows a snackbar', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(groups: [makeGroup()], boats: [makeBoat()]),
      );
      await pumpScreen(tester);

      await tester.scrollUntilVisible(joinButton(), 200);
      await tester.tap(joinButton());
      await pumpScreen(tester);

      expectSnackbar(tester, 'Select a group');
    });

    testWidgets('joining without a boat shows a snackbar', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(groups: [makeGroup()], boats: [makeBoat()]),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('Palma Sailing Club'));
      await pumpScreen(tester);

      await tester.scrollUntilVisible(joinButton(), 200);
      await tester.tap(joinButton());
      await pumpScreen(tester);

      expectSnackbar(tester, 'Select a boat');
    });
  });

  group('StartEventRegattaScreen join', () {
    Future<void> selectAndJoin(WidgetTester tester) async {
      await tester.tap(find.text('Palma Sailing Club'));
      await pumpScreen(tester);
      await tester.tap(find.text('Luna Azul'));
      await pumpScreen(tester);
      await tester.scrollUntilVisible(joinButton(), 200);
      await tester.tap(joinButton());
      await pumpScreen(tester);
    }

    testWidgets('creates the regatta and replaces with the detail screen',
        (tester) async {
      setPhoneSize(tester);
      stubSchedule();
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildSubject(
          spy: spy,
          groups: [makeGroup()],
          boats: [makeBoat(homePort: 'Port de Soller')],
        ),
      );
      await pumpScreen(tester);

      await selectAndJoin(tester);

      // The boat home port wins the departure-port fallback chain.
      verify(() => mockRepo.schedule(
            groupId: 'group-1',
            boatId: 'boat-1',
            departurePort: 'Port de Soller',
            title: 'Copa del Rey',
            scheduledAt: any(named: 'scheduledAt'),
          )).called(1);
      expectSnackbar(tester, "You've joined with your group");
      expect(spy.last, '/regattas/r9');
    });

    testWidgets('without a boat home port it falls back to the event location',
        (tester) async {
      setPhoneSize(tester);
      stubSchedule();
      await tester.pumpWidget(
        buildSubject(
          groups: [makeGroup()],
          boats: [makeBoat(homePort: null)],
        ),
      );
      await pumpScreen(tester);

      await selectAndJoin(tester);

      verify(() => mockRepo.schedule(
            groupId: any(named: 'groupId'),
            boatId: any(named: 'boatId'),
            departurePort: 'Palma de Mallorca',
            title: any(named: 'title'),
            scheduledAt: any(named: 'scheduledAt'),
          )).called(1);
    });

    testWidgets('without event data it falls back to the generic port label',
        (tester) async {
      setPhoneSize(tester);
      stubSchedule();
      final completer = Completer<Event>();
      await tester.pumpWidget(
        buildSubject(
          groups: [makeGroup()],
          boats: [makeBoat(homePort: null)],
          fetchEvent: () => completer.future,
        ),
      );
      await pumpScreen(tester);

      await selectAndJoin(tester);

      verify(() => mockRepo.schedule(
            groupId: any(named: 'groupId'),
            boatId: any(named: 'boatId'),
            departurePort: 'Puerto de salida',
            title: any(named: 'title'),
            scheduledAt: any(named: 'scheduledAt'),
          )).called(1);

      await drain(tester);
    });

    testWidgets('failure shows a snackbar and stays on the screen',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.schedule(
            groupId: any(named: 'groupId'),
            boatId: any(named: 'boatId'),
            departurePort: any(named: 'departurePort'),
            title: any(named: 'title'),
            scheduledAt: any(named: 'scheduledAt'),
          )).thenThrow(Exception('boom'));
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildSubject(spy: spy, groups: [makeGroup()], boats: [makeBoat()]),
      );
      await pumpScreen(tester);

      await selectAndJoin(tester);

      expectSnackbar(tester, 'Could not join');
      expect(spy.locations, isEmpty);
    });
  });
}
