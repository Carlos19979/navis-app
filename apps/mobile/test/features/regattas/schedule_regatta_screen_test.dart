import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/ports/domain/entities/port.dart';
import 'package:navis_mobile/features/ports/presentation/providers/port_provider.dart';
import 'package:navis_mobile/features/regattas/data/repositories/regatta_repository.dart';
import 'package:navis_mobile/features/regattas/presentation/providers/regatta_provider.dart';
import 'package:navis_mobile/features/regattas/presentation/screens/schedule_regatta_screen.dart';
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

  const groupId = 'g1';

  late _MockRegattaRepository mockRepo;

  setUp(() {
    mockRepo = _MockRegattaRepository();
  });

  Port makePort({String id = 'port-1', String name = 'Port Nou'}) {
    return Port(
      id: id,
      name: name,
      lat: 39.5,
      lon: 2.6,
      country: 'ES',
      portType: PortType.marina,
    );
  }

  /// A boat with home-port coordinates but no home-port name, so the port
  /// picker auto-selects the nearest port returned by the ports provider.
  Boat makeGeoBoat() {
    return makeBoat(homePort: null).copyWith(
      homePortLat: 39.6,
      homePortLon: 2.7,
    );
  }

  Widget buildSubject({
    RouteSpy? spy,
    List<Boat> boats = const [],
    List<Port> ports = const [],
  }) {
    return buildRoutedTestApp(
      const ScheduleRegattaScreen(groupId: groupId),
      spy: spy,
      overrides: [
        regattaRepositoryProvider.overrideWithValue(mockRepo),
        boatsProvider.overrideWith(() => _FakeBoatsNotifier(boats)),
        nearbyPortsProvider.overrideWith((ref, params) async => ports),
      ],
    );
  }

  Finder submitButton() => find.widgetWithText(NavisButton, 'Schedule regatta');

  void stubSchedule() {
    when(() => mockRepo.schedule(
          groupId: any(named: 'groupId'),
          boatId: any(named: 'boatId'),
          departurePort: any(named: 'departurePort'),
          title: any(named: 'title'),
          scheduledAt: any(named: 'scheduledAt'),
        )).thenAnswer((_) async => makeRegatta());
  }

  group('ScheduleRegattaScreen boat picker', () {
    testWidgets('no boats shows the add-boat CTA that navigates to /boats/new',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(buildSubject(spy: spy));
      await pumpScreen(tester);

      expect(find.text('Add a boat first.'), findsOneWidget);

      await tester.tap(find.text('Add Boat'));
      await pumpScreen(tester);

      expect(spy.last, '/boats/new');
    });

    testWidgets('boats render as selectable cards', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: [makeBoat()]));
      await pumpScreen(tester);

      expect(find.text('Luna Azul'), findsOneWidget);
    });

    testWidgets('port picker is gated until a boat is selected',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: [makeBoat()]));
      await pumpScreen(tester);

      expect(find.text('Select a boat first.'), findsOneWidget);

      await tester.tap(find.text('Luna Azul'));
      await pumpScreen(tester);

      expect(find.text('Select a boat first.'), findsNothing);
    });
  });

  group('ScheduleRegattaScreen validation', () {
    testWidgets('submitting without a boat shows a snackbar', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: [makeBoat()]));
      await pumpScreen(tester);

      await tester.scrollUntilVisible(
        submitButton(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(submitButton());
      await pumpScreen(tester);

      expectSnackbar(tester, 'Select a boat');
    });

    testWidgets('submitting without a departure port shows a snackbar',
        (tester) async {
      setPhoneSize(tester);
      // Boat without home-port coordinates: nothing is auto-selected and the
      // pre-filled custom name does not count as a selection.
      final boat = makeBoat(homePort: null);
      await tester.pumpWidget(buildSubject(boats: [boat]));
      await pumpScreen(tester);

      await tester.tap(find.text('Luna Azul'));
      await pumpScreen(tester);

      await tester.scrollUntilVisible(
        submitButton(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(submitButton());
      await pumpScreen(tester);

      expectSnackbar(tester, 'Select the departure port');
    });
  });

  group('ScheduleRegattaScreen submit', () {
    testWidgets('success schedules the regatta and pops back', (tester) async {
      setPhoneSize(tester);
      stubSchedule();
      await tester.pumpWidget(
        buildSubject(boats: [makeGeoBoat()], ports: [makePort()]),
      );
      await pumpScreen(tester);

      await tester.enterText(
        find.byType(TextField).first,
        'Spring Cup',
      );
      await tester.tap(find.text('Luna Azul'));
      // Extra pump: the nearest port auto-selects in a post-frame callback.
      await pumpScreen(tester);
      await pumpScreen(tester);

      await tester.scrollUntilVisible(
        submitButton(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(submitButton());
      await pumpScreen(tester);

      verify(() => mockRepo.schedule(
            groupId: groupId,
            boatId: 'boat-1',
            departurePort: 'Port Nou',
            title: 'Spring Cup',
            scheduledAt: any(named: 'scheduledAt'),
          )).called(1);
      expectSnackbar(tester, 'Regatta scheduled');
      // context.pop() lands back on the host page.
      expect(find.text('__host__'), findsOneWidget);
    });

    testWidgets('failure shows a snackbar and stays on the form',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.schedule(
            groupId: any(named: 'groupId'),
            boatId: any(named: 'boatId'),
            departurePort: any(named: 'departurePort'),
            title: any(named: 'title'),
            scheduledAt: any(named: 'scheduledAt'),
          )).thenThrow(Exception('boom'));
      await tester.pumpWidget(
        buildSubject(boats: [makeGeoBoat()], ports: [makePort()]),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('Luna Azul'));
      await pumpScreen(tester);
      await pumpScreen(tester);

      await tester.scrollUntilVisible(
        submitButton(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(submitButton());
      await pumpScreen(tester);

      expectSnackbar(tester, 'Could not schedule');
      expect(find.text('__host__'), findsNothing);
    });
  });
}
