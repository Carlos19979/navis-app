import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/events/domain/entities/event.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/features/community/presentation/screens/community_screen.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/features/events/presentation/widgets/event_card.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

import '../../helpers/helpers.dart';

/// The regatta feed, as it ships: a section of the Community screen.
///
/// These tests used to drive `EventsScreen`, a wrapper the Community tab
/// embedded. When Community became one feed nothing referenced it any more, so
/// the wrapper went and its coverage came here — the assertions are about the
/// regatta rows and their states, and those did not change.
void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  Widget subject(Override events) => buildTestApp(
        const CommunityScreen(),
        overrides: [
          events,
          myGroupsProvider.overrideWith((ref) async => <Group>[]),
          discoverGroupsProvider.overrideWith((ref) async => <Group>[]),
          ...planOverrides(),
        ],
      );

  group('the regatta feed', () {
    testWidgets('shows shimmer loading state', (tester) async {
      final completer = Completer<List<Event>>();
      // Let it finish on the way out: a request left hanging keeps the
      // shimmer's own animation alive past the end of the test.
      addTearDown(() {
        if (!completer.isCompleted) completer.complete(const []);
      });

      await tester.pumpWidget(
        subject(
          eventsProvider.overrideWith(
            (ref) => completer.future,
          ),
        ),
      );
      await tester.pump();

      // One per section still loading.
      expect(find.byType(NavisShimmer), findsWidgets);

      completer.complete(const []);
      await pumpFrames(tester, frames: 8);
      await drain(tester);
    });

    testWidgets('is titled by its section heading', (tester) async {
      await tester.pumpWidget(
        subject(
          eventsProvider.overrideWith(
            (ref) async => [makeEvent()],
          ),
        ),
      );
      await pumpFrames(tester, frames: 8);

      expect(find.text('REGATTAS'), findsOneWidget);
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
        subject(
          eventsProvider.overrideWith(
            (ref) async => events,
          ),
        ),
      );
      await pumpFrames(tester, frames: 8);

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
        subject(
          eventsProvider.overrideWith(
            (ref) async => events,
          ),
        ),
      );
      await pumpFrames(tester, frames: 8);

      // The star is inline with the name now, not floating in a glowing disc.
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('shows empty state when no events', (tester) async {
      await tester.pumpWidget(
        subject(
          eventsProvider.overrideWith(
            (ref) async => <Event>[],
          ),
        ),
      );
      await pumpFrames(tester, frames: 8);

      // A section with nothing in it says so in one line; the club sections
      // below it are still on screen, so a full-page empty state would lie.
      expect(find.byType(NavisEmptyState), findsNothing);
      expect(
        find.textContaining('Regattas are scheduled by a club'),
        findsOneWidget,
      );
    });

    testWidgets('has list/calendar toggle button', (tester) async {
      await tester.pumpWidget(
        subject(
          eventsProvider.overrideWith(
            (ref) async => [makeEvent()],
          ),
        ),
      );
      await pumpFrames(tester, frames: 8);

      // Initially in list mode, so shows the calendar icon to switch views.
      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
    });

    testWidgets('toggle view switches icon', (tester) async {
      await tester.pumpWidget(
        subject(
          eventsProvider.overrideWith(
            (ref) async => [makeEvent()],
          ),
        ),
      );
      await pumpFrames(tester, frames: 8);

      // Initially list view: calendar icon shown.
      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);

      // Tap toggle to switch to calendar view.
      await tester.tap(find.byIcon(Icons.calendar_month_rounded));
      await pumpFrames(tester, frames: 8);

      // Now calendar view: back-to-list icon shown. The month is a view of
      // this section — the club sections are still below it, off screen only
      // because a month grid is tall.
      expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);

      await drain(tester);
    });

    testWidgets('shows error state with retry button', (tester) async {
      await tester.pumpWidget(
        subject(
          eventsProvider.overrideWith(
            (ref) async => throw Exception('Failed to load events'),
          ),
        ),
      );
      await pumpFrames(tester, frames: 8);

      expect(find.byType(NavisErrorWidget), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button triggers provider refresh', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        subject(
          eventsProvider.overrideWith(
            (ref) async {
              callCount++;
              throw Exception('Network error');
            },
          ),
        ),
      );
      await pumpFrames(tester, frames: 8);

      final initialCount = callCount;

      await tester.tap(find.text('Retry'));
      await pumpFrames(tester, frames: 8);

      expect(callCount, greaterThan(initialCount));
    });

    testWidgets('event card shows location name', (tester) async {
      await tester.pumpWidget(
        subject(
          eventsProvider.overrideWith(
            (ref) async => [makeEvent()],
          ),
        ),
      );
      await pumpFrames(tester, frames: 8);

      // Time and place read as one metadata line under the name.
      expect(
        find.textContaining('Palma de Mallorca'),
        findsOneWidget,
      );
    });
  });
}
