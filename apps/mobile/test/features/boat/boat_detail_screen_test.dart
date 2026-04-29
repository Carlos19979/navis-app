// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/domain/repositories/boat_repository.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/boat/presentation/screens/boat_detail_screen.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';

import '../../helpers/test_helpers.dart';

class MockBoatRepository extends Mock implements BoatRepository {}

class FakeRoute extends Fake implements Route<dynamic> {}

class FakeBoatsNotifier extends AsyncNotifier<List<Boat>>
    implements BoatsNotifier {
  FakeBoatsNotifier(this._boats);
  final List<Boat> _boats;
  bool deleteBoatCalled = false;
  String? deletedBoatId;

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
  Future<void> deleteBoat(String id) async {
    deleteBoatCalled = true;
    deletedBoatId = id;
  }
}

/// Pump enough frames for async providers and initial animations
/// without pumpAndSettle (flutter_animate has repeating animations).
Future<void> pumpScreen(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> setPhoneSize(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  final testBoat = makeBoat(
    id: 'boat-1',
    name: 'Luna Azul',
    registration: 'ES-MAL-3-1234',
    type: 'sailboat',
    homePort: 'Palma de Mallorca',
  );

  late FakeBoatsNotifier fakeBoatsNotifier;

  setUp(() {
    fakeBoatsNotifier = FakeBoatsNotifier([testBoat]);
  });

  /// Creates a GoRouter with the BoatDetailScreen at /boats/:id
  /// and placeholder pages for navigation targets.
  Widget buildSubject({
    Boat? boat,
    bool useError = false,
  }) {
    final effectiveBoat = boat ?? testBoat;
    final router = GoRouter(
      initialLocation: '/boats/${effectiveBoat.id}',
      routes: [
        GoRoute(
          path: '/boats',
          builder: (_, __) =>
              const Scaffold(body: Text('Boats Page')),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) => BoatDetailScreen(
                boatId: state.pathParameters['id']!,
              ),
              routes: [
                GoRoute(
                  path: 'documents',
                  builder: (_, __) => const Scaffold(
                      body: Text('Documents Page')),
                ),
                GoRoute(
                  path: 'trips',
                  builder: (_, __) =>
                      const Scaffold(body: Text('Trips Page')),
                ),
                GoRoute(
                  path: 'edit',
                  builder: (_, __) =>
                      const Scaffold(body: Text('Edit Page')),
                ),
                GoRoute(
                  path: 'record',
                  builder: (_, __) =>
                      const Scaffold(body: Text('Record Page')),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        boatProvider.overrideWith(
          (ref, id) async {
            if (useError) throw Exception('Failed to load boat');
            return effectiveBoat;
          },
        ),
        boatsProvider.overrideWith(() => fakeBoatsNotifier),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('BoatDetailScreen', () {
    testWidgets('shows loading state initially', (tester) async {
      await setPhoneSize(tester);
      final router = GoRouter(
        initialLocation: '/boats/boat-1',
        routes: [
          GoRoute(
            path: '/boats/:id',
            builder: (_, state) => BoatDetailScreen(
              boatId: state.pathParameters['id']!,
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            boatProvider.overrideWith(
              (ref, id) => Future<Boat>.delayed(
                  const Duration(days: 1)),
            ),
            boatsProvider
                .overrideWith(() => fakeBoatsNotifier),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(BoatDetailScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows error state with retry button',
        (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(useError: true));
      await pumpScreen(tester);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button is tappable in error state',
        (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(useError: true));
      await pumpScreen(tester);

      await tester.tap(find.text('Retry'));
      await pumpScreen(tester);
    });

    testWidgets('shows boat name', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('Luna Azul'), findsOneWidget);
    });

    testWidgets('shows boat registration', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('ES-MAL-3-1234'), findsOneWidget);
    });

    testWidgets('shows boat type capitalized', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('Sailboat'), findsOneWidget);
    });

    testWidgets('shows boat length', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('12.5 m'), findsOneWidget);
    });

    testWidgets('shows home port when available', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('Palma de Mallorca'), findsOneWidget);
    });

    testWidgets('hides home port when null', (tester) async {
      await setPhoneSize(tester);
      final boatNoPort = makeBoat(
        id: 'boat-2',
        name: 'Nomad',
        homePort: null,
      );

      await tester.pumpWidget(buildSubject(boat: boatNoPort));
      await pumpScreen(tester);

      expect(find.text('Home Port'), findsNothing);
    });

    testWidgets('shows Documents action tile', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('Documents'), findsOneWidget);
      expect(
        find.text('Certificates, insurance, inspections'),
        findsOneWidget,
      );
    });

    testWidgets('shows Logbook action tile', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('Logbook'), findsOneWidget);
      expect(
          find.text('Trip history and statistics'), findsOneWidget);
    });

    testWidgets('shows Edit Boat action tile', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('Edit Boat'), findsOneWidget);
      expect(find.text('Modify boat details'), findsOneWidget);
    });

    testWidgets('shows Delete Boat action tile', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('Delete Boat'), findsOneWidget);
      expect(
        find.text('Remove this boat permanently'),
        findsOneWidget,
      );
    });

    testWidgets('Documents tile navigates to documents page',
        (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(find.text('Documents'));
      await pumpScreen(tester);

      expect(find.text('Documents Page'), findsOneWidget);
    });

    testWidgets('Edit Boat tile navigates to edit page',
        (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(find.text('Edit Boat'));
      await pumpScreen(tester);

      expect(find.text('Edit Page'), findsOneWidget);
    });

    testWidgets('shows Start Trip FAB', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('Start Trip'), findsOneWidget);
    });

    testWidgets('Start Trip FAB navigates to record page',
        (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(find.text('Start Trip'));
      await pumpScreen(tester);

      expect(find.text('Record Page'), findsOneWidget);
    });

    group('delete boat', () {
      testWidgets('tapping Delete Boat shows confirmation dialog',
          (tester) async {
        await setPhoneSize(tester);
        await tester.pumpWidget(buildSubject());
        await pumpScreen(tester);

        // Scroll down to see Delete Boat tile
        await tester.scrollUntilVisible(
          find.text('Delete Boat'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();

        await tester.tap(find.text('Delete Boat'));
        await pumpScreen(tester);

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.textContaining('Are you sure you want to delete'),
          findsOneWidget,
        );
      });

      testWidgets('cancel button dismisses the delete dialog',
          (tester) async {
        await setPhoneSize(tester);
        await tester.pumpWidget(buildSubject());
        await pumpScreen(tester);

        await tester.scrollUntilVisible(
          find.text('Delete Boat'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();

        await tester.tap(find.text('Delete Boat'));
        await pumpScreen(tester);

        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await pumpScreen(tester);

        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('confirm delete calls deleteBoat on notifier',
          (tester) async {
        await setPhoneSize(tester);
        await tester.pumpWidget(buildSubject());
        await pumpScreen(tester);

        await tester.scrollUntilVisible(
          find.text('Delete Boat'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();

        await tester.tap(find.text('Delete Boat'));
        await pumpScreen(tester);

        // Tap Delete in the dialog
        await tester
            .tap(find.widgetWithText(FilledButton, 'Delete'));
        await pumpScreen(tester);

        expect(fakeBoatsNotifier.deleteBoatCalled, isTrue);
        expect(fakeBoatsNotifier.deletedBoatId, 'boat-1');
      });

      testWidgets('dialog shows boat name in confirmation text',
          (tester) async {
        await setPhoneSize(tester);
        await tester.pumpWidget(buildSubject());
        await pumpScreen(tester);

        await tester.scrollUntilVisible(
          find.text('Delete Boat'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();

        await tester.tap(find.text('Delete Boat'));
        await pumpScreen(tester);

        expect(
          find.textContaining('"Luna Azul"'),
          findsOneWidget,
        );
        expect(
          find.textContaining('documents and trips'),
          findsOneWidget,
        );
      });

      testWidgets('dialog has Cancel and Delete buttons',
          (tester) async {
        await setPhoneSize(tester);
        await tester.pumpWidget(buildSubject());
        await pumpScreen(tester);

        await tester.scrollUntilVisible(
          find.text('Delete Boat'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();

        await tester.tap(find.text('Delete Boat'));
        await pumpScreen(tester);

        expect(find.text('Cancel'), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'Delete'),
          findsOneWidget,
        );
      });
    });

    testWidgets('displays info section labels', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('Registration'), findsOneWidget);
      expect(find.text('Type'), findsOneWidget);
      expect(find.text('Length'), findsOneWidget);
      expect(find.text('Home Port'), findsOneWidget);
    });

    testWidgets('shows correct values in info rows',
        (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('ES-MAL-3-1234'), findsOneWidget);
      expect(find.text('Sailboat'), findsOneWidget);
      expect(find.text('12.5 m'), findsOneWidget);
      expect(find.text('Palma de Mallorca'), findsOneWidget);
    });

    testWidgets('renders with motorboat type', (tester) async {
      await setPhoneSize(tester);
      final motorboat = makeBoat(
        id: 'boat-3',
        name: 'Speed Demon',
        type: 'motorboat',
      );

      await tester.pumpWidget(buildSubject(boat: motorboat));
      await pumpScreen(tester);

      expect(find.text('Speed Demon'), findsOneWidget);
      expect(find.text('Motorboat'), findsOneWidget);
    });
  });
}
