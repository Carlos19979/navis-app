// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/boat/presentation/screens/boat_form_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_photo_strip.dart';

import '../../helpers/helpers.dart';

/// Records createBoat/updateBoat/deleteBoat calls; throws when [failing].
class _RecordingBoatsNotifier extends AsyncNotifier<List<Boat>>
    implements BoatsNotifier {
  _RecordingBoatsNotifier({this.failing = false});

  final bool failing;
  final created = <Boat>[];
  final updated = <Boat>[];
  final deleted = <String>[];

  @override
  Future<List<Boat>> build() async => [];
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<Boat> createBoat(Boat boat) async {
    if (failing) throw Exception('server error');
    created.add(boat);
    return boat.copyWith(id: 'boat-created');
  }

  @override
  Future<void> updateBoat(Boat boat) async {
    if (failing) throw Exception('server error');
    updated.add(boat);
  }

  @override
  Future<void> deleteBoat(String id) async {
    if (failing) throw Exception('server error');
    deleted.add(id);
  }
}

void main() {
  setUpAll(() async {
    registerFallbackValue(FakeRoute());
    await signInFakeUser();
  });

  Widget buildSubject({
    String boatId = 'new',
    required _RecordingBoatsNotifier notifier,
    RouteSpy? spy,
  }) {
    return buildRoutedTestApp(
      BoatFormScreen(boatId: boatId),
      spy: spy,
      overrides: [
        boatsProvider.overrideWith(() => notifier),
        boatProvider.overrideWith((ref, id) async => makeBoat(id: id)),
      ],
    );
  }

  group('BoatFormScreen create mode', () {
    testWidgets('empty name shows validation error', (tester) async {
      setPhoneSize(tester);
      final notifier = _RecordingBoatsNotifier();
      await tester.pumpWidget(buildSubject(notifier: notifier));
      await pumpScreen(tester);

      await tester.ensureVisible(find.text('Create Boat'));
      await tester.tap(find.text('Create Boat'));
      await pumpScreen(tester);

      expect(find.text('Please enter the boat name'), findsOneWidget);
      expect(notifier.created, isEmpty);
    });

    testWidgets('empty registration shows validation error', (tester) async {
      setPhoneSize(tester);
      final notifier = _RecordingBoatsNotifier();
      await tester.pumpWidget(buildSubject(notifier: notifier));
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Boat Name'),
        'Luna Azul',
      );
      await tester.ensureVisible(find.text('Create Boat'));
      await tester.tap(find.text('Create Boat'));
      await pumpScreen(tester);

      expect(
        find.text('Please enter the registration number'),
        findsOneWidget,
      );
      expect(notifier.created, isEmpty);
    });

    testWidgets('empty length shows validation error', (tester) async {
      setPhoneSize(tester);
      final notifier = _RecordingBoatsNotifier();
      await tester.pumpWidget(buildSubject(notifier: notifier));
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Boat Name'),
        'Luna Azul',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Registration Number'),
        'ES-MAL-3-1234',
      );
      await tester.ensureVisible(find.text('Create Boat'));
      await tester.tap(find.text('Create Boat'));
      await pumpScreen(tester);

      expect(find.text('Please enter the length'), findsOneWidget);
      expect(notifier.created, isEmpty);
    });

    testWidgets('non-numeric length shows validation error', (tester) async {
      setPhoneSize(tester);
      final notifier = _RecordingBoatsNotifier();
      await tester.pumpWidget(buildSubject(notifier: notifier));
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Boat Name'),
        'Luna Azul',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Registration Number'),
        'ES-MAL-3-1234',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Length (m)'),
        'twelve',
      );
      await tester.ensureVisible(find.text('Create Boat'));
      await tester.tap(find.text('Create Boat'));
      await pumpScreen(tester);

      expect(find.text('Please enter a valid number'), findsOneWidget);
      expect(notifier.created, isEmpty);
    });

    testWidgets('type dropdown selects a boat type', (tester) async {
      setPhoneSize(tester);
      final notifier = _RecordingBoatsNotifier();
      await tester.pumpWidget(buildSubject(notifier: notifier));
      await pumpScreen(tester);

      expect(find.text('Sailboat'), findsOneWidget);

      await tester.tap(find.text('Sailboat'));
      await pumpScreen(tester);
      await tester.tap(find.text('Motorboat').last);
      await pumpScreen(tester);

      expect(find.text('Motorboat'), findsOneWidget);
      expect(find.text('Sailboat'), findsNothing);
    });

    testWidgets(
        'save success calls createBoat, shows snackbar and navigates home',
        (tester) async {
      setPhoneSize(tester);
      final notifier = _RecordingBoatsNotifier();
      final spy = RouteSpy();
      await tester.pumpWidget(buildSubject(notifier: notifier, spy: spy));
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Boat Name'),
        'Luna Azul',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Registration Number'),
        'ES-MAL-3-1234',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Length (m)'),
        '12.5',
      );
      await tester.ensureVisible(find.text('Create Boat'));
      await tester.tap(find.text('Create Boat'));
      await pumpScreen(tester);

      expect(notifier.created, hasLength(1));
      expect(notifier.created.single.name, 'Luna Azul');
      expect(notifier.created.single.registration, 'ES-MAL-3-1234');
      expect(notifier.created.single.lengthMeters, 12.5);
      expectSnackbar(tester, 'Boat created successfully');
      expect(spy.last, '/boats');

      await drain(tester);
    });

    testWidgets('save failure shows error snackbar and stays on form',
        (tester) async {
      setPhoneSize(tester);
      final notifier = _RecordingBoatsNotifier(failing: true);
      final spy = RouteSpy();
      await tester.pumpWidget(buildSubject(notifier: notifier, spy: spy));
      await pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Boat Name'),
        'Luna Azul',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Registration Number'),
        'ES-MAL-3-1234',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Length (m)'),
        '12.5',
      );
      await tester.ensureVisible(find.text('Create Boat'));
      await tester.tap(find.text('Create Boat'));
      await pumpScreen(tester);

      expectSnackbar(tester, 'Failed to save boat');
      expect(spy.locations, isEmpty);
      expect(find.byType(BoatFormScreen), findsOneWidget);

      await drain(tester);
    });
  });

  group('BoatFormScreen edit mode', () {
    testWidgets('prefills fields and shows Update Boat button', (tester) async {
      setPhoneSize(tester);
      final notifier = _RecordingBoatsNotifier();
      await tester
          .pumpWidget(buildSubject(boatId: 'boat-1', notifier: notifier));
      await pumpScreen(tester);

      expect(find.text('Edit Boat'), findsOneWidget);
      expect(find.text('Luna Azul'), findsOneWidget);
      expect(find.text('ES-MAL-3-1234'), findsOneWidget);
      expect(find.text('12.5'), findsOneWidget);
      expect(find.text('Palma de Mallorca'), findsOneWidget);
      expect(find.text('Update Boat'), findsOneWidget);
      expect(find.text('Delete Boat'), findsOneWidget);
    });

    testWidgets('delete confirm dialog cancel keeps the boat', (tester) async {
      setPhoneSize(tester);
      final notifier = _RecordingBoatsNotifier();
      await tester
          .pumpWidget(buildSubject(boatId: 'boat-1', notifier: notifier));
      await pumpScreen(tester);

      await tester.ensureVisible(find.text('Delete Boat'));
      await tester.tap(find.text('Delete Boat'));
      await pumpScreen(tester);

      expect(
          find.text('Are you sure you want to delete this?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await pumpScreen(tester);

      expect(notifier.deleted, isEmpty);
      expect(find.byType(BoatFormScreen), findsOneWidget);
    });

    testWidgets('delete confirm calls deleteBoat and navigates home',
        (tester) async {
      setPhoneSize(tester);
      final notifier = _RecordingBoatsNotifier();
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildSubject(boatId: 'boat-1', notifier: notifier, spy: spy),
      );
      await pumpScreen(tester);

      await tester.ensureVisible(find.text('Delete Boat'));
      await tester.tap(find.text('Delete Boat'));
      await pumpScreen(tester);
      await tester.tap(find.text('Delete'));
      await pumpScreen(tester);

      expect(notifier.deleted, ['boat-1']);
      expect(spy.last, '/boats');

      await drain(tester);
    });
  });

  group('BoatFormScreen gallery', () {
    Widget buildGallerySubject({
      required _RecordingBoatsNotifier notifier,
      required bool pro,
      List<String> photoUrls = const [],
    }) {
      return buildRoutedTestApp(
        const BoatFormScreen(boatId: 'boat-1'),
        overrides: [
          ...planOverrides(pro: pro),
          boatsProvider.overrideWith(() => notifier),
          boatProvider.overrideWith(
            (ref, id) async => makeBoat(id: id, photoUrls: photoUrls),
          ),
        ],
      );
    }

    testWidgets('edit mode renders the gallery with its photos',
        (tester) async {
      setPhoneSize(tester);
      installTileNoiseFilter();
      final notifier = _RecordingBoatsNotifier();
      await tester.pumpWidget(buildGallerySubject(
        notifier: notifier,
        pro: true,
        photoUrls: const ['https://x.test/a.jpg', 'https://x.test/b.jpg'],
      ));
      await pumpScreen(tester);

      expect(find.text('Gallery'), findsOneWidget);
      expect(find.byType(NavisPhotoThumb), findsNWidgets(2));
      expect(find.byTooltip('Add Photo'), findsOneWidget);
    });

    testWidgets('removing a photo drops it from the saved boat',
        (tester) async {
      setPhoneSize(tester);
      installTileNoiseFilter();
      final notifier = _RecordingBoatsNotifier();
      await tester.pumpWidget(buildGallerySubject(
        notifier: notifier,
        pro: true,
        photoUrls: const ['https://x.test/a.jpg', 'https://x.test/b.jpg'],
      ));
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Remove').first);
      await pumpScreen(tester);
      expect(find.byType(NavisPhotoThumb), findsOneWidget);

      await tester.ensureVisible(find.text('Update Boat'));
      await tester.tap(find.text('Update Boat'));
      await pumpScreen(tester);

      expect(notifier.updated, hasLength(1));
      expect(notifier.updated.single.photoUrls, ['https://x.test/b.jpg']);

      await drain(tester);
    });

    testWidgets('Free plan: adding a gallery photo shows the paywall',
        (tester) async {
      setPhoneSize(tester);
      final notifier = _RecordingBoatsNotifier();
      await tester.pumpWidget(buildGallerySubject(
        notifier: notifier,
        pro: false,
      ));
      await pumpScreen(tester);

      await tester.ensureVisible(find.byTooltip('Add Photo'));
      await tester.tap(find.byTooltip('Add Photo'));
      await pumpScreen(tester);

      expectPaywall();
      expect(find.text('Take Photo'), findsNothing);

      await drain(tester);
    });
  });
}
