import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/events/domain/entities/event.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/features/events/presentation/screens/events_screen.dart';
import 'package:navis_mobile/features/events/presentation/widgets/event_card.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

import '../../helpers/test_helpers.dart';

class FakeRoute extends Fake implements Route<dynamic> {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  Future<void> pumpFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('EventsScreen', () {
    testWidgets('shows shimmer loading state', (tester) async {
      final completer = Completer<List<Event>>();

      await tester.pumpWidget(
        buildTestApp(
          const EventsScreen(),
          overrides: [
            eventsProvider.overrideWith(
              (ref) => completer.future,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(NavisShimmer), findsOneWidget);
    });

    testWidgets('displays Events title in app bar', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const EventsScreen(),
          overrides: [
            eventsProvider.overrideWith(
              (ref) async => [makeEvent()],
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.text('Events'), findsOneWidget);
    });

    testWidgets('renders event list with EventCard widgets', (tester) async {
      final events = [
        makeEvent(),
        makeEvent(
          id: 'event-2',
          name: 'Trofeo Princesa Sofia',
          isFeatured: false,
        ),
      ];

      await tester.pumpWidget(
        buildTestApp(
          const EventsScreen(),
          overrides: [
            eventsProvider.overrideWith(
              (ref) async => events,
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.byType(EventCard), findsNWidgets(2));
      expect(find.text('Copa del Rey'), findsOneWidget);
      expect(find.text('Trofeo Princesa Sofia'), findsOneWidget);
    });

    testWidgets('shows featured star icon for featured events', (tester) async {
      final events = [
        makeEvent(),
        makeEvent(
          id: 'event-2',
          name: 'Local Meetup',
          isFeatured: false,
        ),
      ];

      await tester.pumpWidget(
        buildTestApp(
          const EventsScreen(),
          overrides: [
            eventsProvider.overrideWith(
              (ref) async => events,
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      // Featured events show star icon
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('shows empty state when no events', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const EventsScreen(),
          overrides: [
            eventsProvider.overrideWith(
              (ref) async => <Event>[],
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.byType(NavisEmptyState), findsOneWidget);
      expect(find.text('No upcoming events.'), findsOneWidget);
    });

    testWidgets('has calendar toggle button in app bar', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const EventsScreen(),
          overrides: [
            eventsProvider.overrideWith(
              (ref) async => [makeEvent()],
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.byTooltip('Toggle view'), findsOneWidget);
      // Initially in list mode, so shows calendar icon
      expect(
        find.byIcon(Icons.calendar_month),
        findsOneWidget,
      );
    });

    testWidgets('toggle view switches icon', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const EventsScreen(),
          overrides: [
            eventsProvider.overrideWith(
              (ref) async => [makeEvent()],
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      // Initially list view: calendar icon shown
      expect(find.byIcon(Icons.calendar_month), findsOneWidget);

      // Tap toggle to switch to calendar view
      await tester.tap(find.byTooltip('Toggle view'));
      await pumpFrames(tester);

      // Now calendar view: list icon shown
      expect(find.byIcon(Icons.list), findsOneWidget);
    });

    testWidgets('shows error state with retry button', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const EventsScreen(),
          overrides: [
            eventsProvider.overrideWith(
              (ref) async => throw Exception('Failed to load events'),
            ),
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
          const EventsScreen(),
          overrides: [
            eventsProvider.overrideWith(
              (ref) async {
                callCount++;
                throw Exception('Network error');
              },
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      final initialCount = callCount;

      await tester.tap(find.text('Retry'));
      await pumpFrames(tester);

      expect(callCount, greaterThan(initialCount));
    });

    testWidgets('event card shows location name', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const EventsScreen(),
          overrides: [
            eventsProvider.overrideWith(
              (ref) async => [makeEvent()],
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
  });
}
