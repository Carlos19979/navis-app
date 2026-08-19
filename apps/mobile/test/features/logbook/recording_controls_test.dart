import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/recording_controls.dart';

import '../../helpers/test_helpers.dart';
import '../../helpers/text_layout.dart';

/// Discard used to be a bare white `TextButton` sitting straight on the map
/// tiles: invisible over light coastline and with no guaranteed touch target
/// next to the two 72dp pause/stop circles. These lock in the dock.
void main() {
  Widget controls({
    TripStatus status = TripStatus.recording,
    VoidCallback? onCancel,
  }) {
    return buildTestAppWithScaffold(
      Align(
        alignment: Alignment.bottomCenter,
        child: RecordingControls(
          status: status,
          onStart: () {},
          onPause: () {},
          onResume: () {},
          onStop: () {},
          onCancel: onCancel,
        ),
      ),
    );
  }

  final discardIcon = find.byIcon(Icons.delete_outline);

  group('RecordingControls discard action', () {
    testWidgets('renders over the dock backdrop, never bare on the tiles',
        (tester) async {
      await tester.pumpWidget(controls(onCancel: () {}));

      expect(discardIcon, findsOneWidget);
      expect(
        find.ancestor(of: discardIcon, matching: find.byType(BackdropFilter)),
        findsOneWidget,
      );
    });

    testWidgets('offers a full touch target', (tester) async {
      await tester.pumpWidget(controls(onCancel: () {}));

      final box = tester.getRect(
        find.ancestor(of: discardIcon, matching: find.byType(Container)).first,
      );
      expect(box.height, greaterThanOrEqualTo(Dimens.minTouchTarget));
    });

    testWidgets('fires its callback when tapped', (tester) async {
      var cancelled = false;
      await tester.pumpWidget(controls(onCancel: () => cancelled = true));

      await tester.tap(discardIcon);
      await tester.pump();

      expect(cancelled, isTrue);
    });

    testWidgets('is reachable while paused too', (tester) async {
      await tester.pumpWidget(
        controls(status: TripStatus.paused, onCancel: () {}),
      );

      expect(discardIcon, findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('is absent when the trip cannot be discarded', (tester) async {
      await tester.pumpWidget(controls());

      expect(discardIcon, findsNothing);
      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('label survives the narrowest phone', (tester) async {
      setNarrowPhoneSize(tester);
      await tester.pumpWidget(controls(onCancel: () {}));

      final label = find.descendant(
        of: find.byType(RecordingControls),
        matching: find.byType(Text),
      );
      // Pause label, stop label, discard label.
      expect(label, findsNWidgets(3));
      expectFullyLaidOut(tester, label.last);
    });
  });
}
