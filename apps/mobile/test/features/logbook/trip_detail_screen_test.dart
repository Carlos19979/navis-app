import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/logbook/data/repositories/trip_repository.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/trip_detail_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

import '../../helpers/test_helpers.dart';

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
      expect(find.byTooltip('Delete trip'), findsOneWidget);
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

      await tester.tap(find.byTooltip('Delete trip'));
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
      await tester.tap(find.byTooltip('Delete trip'));
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
      await tester.tap(find.byTooltip('Delete trip'));
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
