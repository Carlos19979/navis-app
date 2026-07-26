import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/features/boat/presentation/widgets/expiry_indicator.dart';
import 'package:navis_mobile/features/charts/presentation/widgets/position_indicator.dart';
import 'package:navis_mobile/features/documents/presentation/widgets/document_status_badge.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/recording_controls.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

import '../helpers/helpers.dart';

/// Battery: every looping animation in the app must stop on its own.
///
/// A controller left on `repeat()` with no bound schedules a frame every 16 ms
/// for as long as the widget is mounted and invalidates whatever blurred layer
/// sits beneath it, which is what showed up as foreground battery drain. These
/// tests fail (by `pumpAndSettle` timing out) the moment a loop goes unbounded
/// again.
void main() {
  /// Pumps [widget], checks it does animate at first, and then that the
  /// animation terminates by itself.
  Future<void> expectAnimatesThenSettles(
    WidgetTester tester,
    Widget widget,
  ) async {
    await tester.pumpWidget(buildTestAppWithScaffold(widget));
    // Two frames: flutter_animate starts its controller after the first one.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester.hasRunningAnimations,
      isTrue,
      reason: 'the animation should play at least once',
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 250));

    expect(
      tester.hasRunningAnimations,
      isFalse,
      reason: 'the loop must be bounded, not run for the whole session',
    );

    await drain(tester);
  }

  group('loading indicators stop', () {
    testWidgets('NavisShimmer settles instead of sweeping forever',
        (tester) async {
      await expectAnimatesThenSettles(
        tester,
        const NavisShimmer(itemCount: 4),
      );
    });

    testWidgets('NavisShimmer stops the moment the data replaces it',
        (tester) async {
      await tester.pumpWidget(buildTestAppWithScaffold(const NavisShimmer()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isTrue);

      // What every caller does when the provider resolves.
      await tester.pumpWidget(buildTestAppWithScaffold(const Text('loaded')));
      await tester.pump();

      expect(find.byType(NavisShimmer), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('NavisLoading settles', (tester) async {
      await expectAnimatesThenSettles(
        tester,
        const NavisLoading(message: 'Cargando'),
      );
    });
  });

  group('decorative loops stop', () {
    testWidgets('NavisEmptyState icon float settles', (tester) async {
      await expectAnimatesThenSettles(
        tester,
        const NavisEmptyState(
          icon: Icons.sailing,
          message: 'empty',
          description: 'nothing here yet',
        ),
      );
    });

    testWidgets('PositionIndicator halo settles', (tester) async {
      await expectAnimatesThenSettles(
        tester,
        const FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(41.38, 2.19),
            initialZoom: 12,
          ),
          children: [PositionIndicator(position: LatLng(41.38, 2.19))],
        ),
      );
    });

    testWidgets('RecordingControls start-button glow settles', (tester) async {
      await expectAnimatesThenSettles(
        tester,
        RecordingControls(
          status: TripStatus.completed,
          onStart: () {},
          onPause: () {},
          onResume: () {},
          onStop: () {},
        ),
      );
    });
  });

  group('urgency loops are bounded too', () {
    testWidgets('ExpiryIndicator pulses for an expired date, then rests',
        (tester) async {
      await expectAnimatesThenSettles(
        tester,
        ExpiryIndicator(
          expiryDate: DateTime.now().subtract(const Duration(days: 30)),
        ),
      );
    });

    testWidgets('ExpiryIndicator never animates for a valid date',
        (tester) async {
      await tester.pumpWidget(
        buildTestAppWithScaffold(
          ExpiryIndicator(
            expiryDate: DateTime.now().add(const Duration(days: 400)),
          ),
        ),
      );
      await tester.pump();

      expect(tester.hasRunningAnimations, isFalse);
      expect(
        find.descendant(
          of: find.byType(ExpiryIndicator),
          matching: find.byType(RepaintBoundary),
        ),
        findsNothing,
        reason: 'nothing animates, so nothing needs isolating',
      );
    });

    testWidgets('DocumentStatusBadge glow settles', (tester) async {
      await expectAnimatesThenSettles(
        tester,
        DocumentStatusBadge(
          expiryDate: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
    });
  });

  group('what keeps animating is isolated behind a RepaintBoundary', () {
    Future<void> expectIsolated(
      WidgetTester tester,
      Widget widget,
      Type type,
    ) async {
      await tester.pumpWidget(buildTestAppWithScaffold(widget));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(type),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
        reason: 'a repaint here must not invalidate the blurred chrome',
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 250));
      await drain(tester);
    }

    testWidgets('NavisShimmer', (tester) async {
      await expectIsolated(tester, const NavisShimmer(), NavisShimmer);
    });

    testWidgets('NavisLoading', (tester) async {
      await expectIsolated(tester, const NavisLoading(), NavisLoading);
    });

    testWidgets('NavisEmptyState', (tester) async {
      await expectIsolated(
        tester,
        const NavisEmptyState(icon: Icons.sailing, message: 'empty'),
        NavisEmptyState,
      );
    });

    testWidgets('ExpiryIndicator when expired', (tester) async {
      await expectIsolated(
        tester,
        ExpiryIndicator(
          expiryDate: DateTime.now().subtract(const Duration(days: 2)),
        ),
        ExpiryIndicator,
      );
    });

    testWidgets('DocumentStatusBadge when expired', (tester) async {
      await expectIsolated(
        tester,
        DocumentStatusBadge(
          expiryDate: DateTime.now().subtract(const Duration(days: 2)),
        ),
        DocumentStatusBadge,
      );
    });
  });
}
