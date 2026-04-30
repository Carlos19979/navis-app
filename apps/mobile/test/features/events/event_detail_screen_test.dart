import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/events/data/repositories/event_repository.dart';
import 'package:navis_mobile/features/events/domain/entities/event.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/features/events/presentation/screens/event_detail_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

import '../../helpers/test_helpers.dart';

class MockEventRepository extends Mock implements EventRepository {}

class FakeRoute extends Fake implements Route<dynamic> {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  late MockEventRepository mockRepo;

  setUp(() {
    mockRepo = MockEventRepository();
  });

  const eventId = 'event-1';

  Future<void> pumpFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Widget buildScreen({
    required List<Override> extraOverrides,
  }) {
    return buildTestApp(
      const EventDetailScreen(eventId: eventId),
      overrides: [
        eventRepositoryProvider.overrideWithValue(mockRepo),
        ...extraOverrides,
      ],
    );
  }

  group('EventDetailScreen', () {
    testWidgets('shows loading indicator while fetching event', (tester) async {
      final completer = Completer<Event>();

      await tester.pumpWidget(
        buildTestApp(
          const EventDetailScreen(eventId: eventId),
          overrides: [
            eventProvider.overrideWith(
              (ref, id) => completer.future,
            ),
            eventRepositoryProvider.overrideWithValue(mockRepo),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(NavisLoading), findsOneWidget);
    });

    testWidgets('displays Event Details title in app bar', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            eventProvider.overrideWith(
              (ref, id) async => makeEvent(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.text('Event Details'), findsOneWidget);
    });

    testWidgets('displays event name', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            eventProvider.overrideWith(
              (ref, id) async => makeEvent(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.text('Copa del Rey'), findsOneWidget);
    });

    testWidgets('displays organizer', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            eventProvider.overrideWith(
              (ref, id) async => makeEvent(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.text('RCNP'), findsOneWidget);
    });

    testWidgets('displays location name', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            eventProvider.overrideWith(
              (ref, id) async => makeEvent(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(
        find.text('Palma de Mallorca'),
        findsOneWidget,
      );
    });

    testWidgets('displays event type badge', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            eventProvider.overrideWith(
              (ref, id) async => makeEvent(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      // _EventTypeBadge capitalizes the first letter
      expect(find.text('Regatta'), findsOneWidget);
    });

    testWidgets('shows featured star badge for featured events',
        (tester) async {
      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            eventProvider.overrideWith(
              (ref, id) async => makeEvent(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      // Featured event shows star icon
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('does not show featured badge for non-featured events',
        (tester) async {
      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            eventProvider.overrideWith(
              (ref, id) async => makeEvent(isFeatured: false),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      // No star icon should be present
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('displays description when present', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            eventProvider.overrideWith(
              (ref, id) async => makeEvent(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(
        find.text('Major regatta event'),
        findsOneWidget,
      );
    });

    testWidgets('displays boat classes when present', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            eventProvider.overrideWith(
              (ref, id) async => makeEvent(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.text('TP52, J80'), findsOneWidget);
    });

    testWidgets('shows Interested button for non-interested event',
        (tester) async {
      final event = makeEvent().copyWith(isInterested: false);

      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            eventProvider.overrideWith(
              (ref, id) async => event,
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.text('Interested'), findsOneWidget);
    });

    testWidgets('shows Not Interested button for already-interested event',
        (tester) async {
      final event = makeEvent().copyWith(isInterested: true);

      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            eventProvider.overrideWith(
              (ref, id) async => event,
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      // Button may be off-screen, scroll to it
      await tester.scrollUntilVisible(
        find.text('Not Interested'),
        200,
      );
      await tester.pump();

      expect(find.text('Not Interested'), findsOneWidget);
    });

    testWidgets('tapping interest button calls repository toggleInterest',
        (tester) async {
      when(() => mockRepo.toggleInterest(eventId)).thenAnswer((_) async {});

      final event = makeEvent().copyWith(isInterested: false);

      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            eventProvider.overrideWith(
              (ref, id) async => event,
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      // Button may be off-screen, scroll to it
      await tester.scrollUntilVisible(
        find.text('Interested'),
        200,
      );
      await tester.pump();

      await tester.tap(find.text('Interested'));
      await pumpFrames(tester);

      verify(() => mockRepo.toggleInterest(eventId)).called(1);
    });

    testWidgets('shows error state with retry button', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const EventDetailScreen(eventId: eventId),
          overrides: [
            eventProvider.overrideWith(
              (ref, id) async => throw Exception('Failed to load event'),
            ),
            eventRepositoryProvider.overrideWithValue(mockRepo),
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
          const EventDetailScreen(eventId: eventId),
          overrides: [
            eventProvider.overrideWith(
              (ref, id) async {
                callCount++;
                throw Exception('Network error');
              },
            ),
            eventRepositoryProvider.overrideWithValue(mockRepo),
          ],
        ),
      );
      await pumpFrames(tester);

      final initialCount = callCount;

      await tester.tap(find.text('Retry'));
      await pumpFrames(tester);

      expect(callCount, greaterThan(initialCount));
    });

    testWidgets('displays calendar icon for date info row', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            eventProvider.overrideWith(
              (ref, id) async => makeEvent(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(
        find.byIcon(Icons.calendar_today),
        findsOneWidget,
      );
    });

    testWidgets('displays location icon for location info row', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            eventProvider.overrideWith(
              (ref, id) async => makeEvent(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(
        find.byIcon(Icons.location_on_outlined),
        findsOneWidget,
      );
    });

    testWidgets('displays person icon for organizer info row', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            eventProvider.overrideWith(
              (ref, id) async => makeEvent(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(
        find.byIcon(Icons.person_outlined),
        findsOneWidget,
      );
    });

    testWidgets('displays sailing icon for boat classes info row',
        (tester) async {
      await tester.pumpWidget(
        buildScreen(
          extraOverrides: [
            eventProvider.overrideWith(
              (ref, id) async => makeEvent(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(
        find.byIcon(Icons.sailing_outlined),
        findsOneWidget,
      );
    });
  });
}
