import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/logbook/data/repositories/trip_repository.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/trip_detail_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

import '../../helpers/helpers.dart';

class MockTripRepository extends Mock implements TripRepository {}

class FakeRoute extends Fake implements Route<dynamic> {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  late MockTripRepository mockRepo;

  setUp(() {
    mockRepo = MockTripRepository();
  });

  const tripId = 'trip-1';

  Future<void> pumpFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Widget buildScreen({
    required List<Override> extraOverrides,
  }) {
    return buildTestApp(
      const TripDetailScreen(tripId: tripId),
      overrides: [
        tripRepositoryProvider.overrideWithValue(mockRepo),
        ...extraOverrides,
      ],
    );
  }

  group('TripDetailScreen', () {
    testWidgets('shows loading indicator while fetching trip', (tester) async {
      final completer = Completer<Trip>();

      await tester.pumpWidget(
        buildTestApp(
          const TripDetailScreen(tripId: tripId),
          overrides: [
            tripProvider.overrideWith(
              (ref, id) => completer.future,
            ),
            tripRepositoryProvider.overrideWithValue(mockRepo),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(NavisLoading), findsOneWidget);
    });

    testWidgets('displays Trip Details title in app bar', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            tripProvider.overrideWith(
              (ref, id) async => makeTrip(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.text('Trip Details'), findsOneWidget);
    });

    testWidgets('displays departure port and arrival port', (tester) async {
      final trip = makeTrip();

      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            tripProvider.overrideWith(
              (ref, id) async => trip,
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      // Route card shows departure and arrival
      expect(find.text('Departure'), findsOneWidget);
      expect(find.text('Arrival'), findsOneWidget);
      expect(
        find.textContaining('Palma de Mallorca'),
        findsWidgets,
      );
      expect(
        find.textContaining('Port de Soller'),
        findsWidgets,
      );
    });

    testWidgets('shows "Not recorded" for arrival when arrivalPort is null',
        (tester) async {
      final trip = makeTrip(arrivalPort: null);

      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            tripProvider.overrideWith(
              (ref, id) async => trip,
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.text('Not recorded'), findsOneWidget);
    });

    testWidgets('displays crew members', (tester) async {
      final trip = makeTrip(); // crewMembers: ['Carlos', 'Maria']

      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            tripProvider.overrideWith(
              (ref, id) async => trip,
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.textContaining('Carlos'), findsWidgets);
      expect(find.textContaining('Maria'), findsWidgets);
    });

    testWidgets('displays notes', (tester) async {
      final trip = makeTrip(); // notes: 'Great trip'

      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            tripProvider.overrideWith(
              (ref, id) async => trip,
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.text('Great trip'), findsOneWidget);
    });

    testWidgets('shows edit, share, and delete buttons in app bar',
        (tester) async {
      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            tripProvider.overrideWith(
              (ref, id) async => makeTrip(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.byTooltip('Edit trip'), findsOneWidget);
      expect(find.byTooltip('Share trip'), findsOneWidget);
      expect(find.byTooltip('Delete Trip'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outlined), findsOneWidget);
    });

    testWidgets('delete button shows confirmation dialog', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            tripProvider.overrideWith(
              (ref, id) async => makeTrip(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Delete Trip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Delete Trip'), findsOneWidget);
      expect(
        find.text('Are you sure you want to delete this trip?'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('cancel button in delete dialog dismisses it', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            tripProvider.overrideWith(
              (ref, id) async => makeTrip(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      // Open dialog
      await tester.tap(find.byTooltip('Delete Trip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Delete Trip'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should be dismissed
      expect(find.text('Delete Trip'), findsNothing);
    });

    testWidgets('confirm delete calls repository deleteTrip', (tester) async {
      when(() => mockRepo.deleteTrip(tripId)).thenAnswer((_) async {});

      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            tripProvider.overrideWith(
              (ref, id) async => makeTrip(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      // Open dialog
      await tester.tap(find.byTooltip('Delete Trip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap Delete
      await tester.tap(find.text('Delete'));
      await pumpFrames(tester);

      verify(() => mockRepo.deleteTrip(tripId)).called(1);
    });

    testWidgets('shows error state with retry button', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const TripDetailScreen(tripId: tripId),
          overrides: [
            tripProvider.overrideWith(
              (ref, id) async => throw Exception('Failed to load trip'),
            ),
            tripRepositoryProvider.overrideWithValue(mockRepo),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.byType(NavisErrorWidget), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button triggers provider refresh', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        buildTestApp(
          const TripDetailScreen(tripId: tripId),
          overrides: [
            tripProvider.overrideWith(
              (ref, id) async {
                callCount++;
                throw Exception('Network error');
              },
            ),
            tripRepositoryProvider.overrideWithValue(mockRepo),
          ],
        ),
      );
      await pumpFrames(tester);

      final initialCount = callCount;

      await tester.tap(find.text('Retry'));
      await pumpFrames(tester);

      expect(callCount, greaterThan(initialCount));
    });

    testWidgets('displays Distance stat when distanceNm is present',
        (tester) async {
      final trip = makeTrip();

      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            tripProvider.overrideWith(
              (ref, id) async => trip,
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.text('Distance'), findsOneWidget);
    });

    testWidgets('renders the map card when track points exist', (tester) async {
      setPhoneSize(tester);
      // Ignore tile/network-image plumbing errors from FlutterMap in tests
      // (same pattern as the W1 chart spike).
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final message = details.exceptionAsString();
        const tolerated = [
          'MissingPluginException',
          'HTTP request failed',
          'NetworkImage',
          'CachedNetworkImageProvider',
          'HttpException',
          'SocketException',
          'Failed host lookup',
          'Connection refused',
          'Connection closed',
          'Couldn\'t download or retrieve file',
          'HttpExceptionWithStatus',
        ];
        if (tolerated.any(message.contains)) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      final trip = makeTrip().copyWith(
        trackPoints: [
          TrackPoint(
            latitude: 39.57,
            longitude: 2.63,
            timestamp: DateTime(2026, 4, 26, 10),
            speedKnots: 4,
          ),
          TrackPoint(
            latitude: 39.60,
            longitude: 2.70,
            timestamp: DateTime(2026, 4, 26, 11),
            speedKnots: 7,
          ),
        ],
      );

      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            tripProvider.overrideWith((ref, id) async => trip),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.byType(FlutterMap), findsOneWidget);
      // Speed legend accompanies the track map.
      expect(find.text('<3 kt'), findsOneWidget);
      expect(find.text('>12 kt'), findsOneWidget);

      // Dispose the map to cancel tile-loading/fade timers before teardown.
      await drain(tester);
    });

    testWidgets('share menu opens with link and summary options',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            tripProvider.overrideWith((ref, id) async => makeTrip()),
          ],
        ),
      );
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Share trip'));
      await pumpFrames(tester);

      expect(find.text('Compartir enlace'), findsOneWidget);
      expect(find.text('Compartir resumen'), findsOneWidget);
    });

    testWidgets('edit action navigates to the trip edit route', (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildRoutedTestApp(
          const TripDetailScreen(tripId: tripId),
          spy: spy,
          overrides: [
            tripProvider.overrideWith((ref, id) async => makeTrip()),
            tripRepositoryProvider.overrideWithValue(mockRepo),
          ],
        ),
      );
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Edit trip'));
      await pumpFrames(tester);

      expect(spy.last, '/trips/$tripId/edit');
    });

    testWidgets('displays max speed stat when present', (tester) async {
      final trip = makeTrip();

      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            tripProvider.overrideWith(
              (ref, id) async => trip,
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.text('Max Speed'), findsOneWidget);
    });
  });
}
