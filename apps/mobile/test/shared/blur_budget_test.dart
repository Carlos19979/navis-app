import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/boat/presentation/widgets/document_card.dart';
import 'package:navis_mobile/features/documents/presentation/widgets/document_status_badge.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/trip_card.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_alert.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_list.dart';
import 'package:navis_mobile/shared/widgets/navis_metric.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';
import 'package:navis_mobile/shared/widgets/navis_text_field.dart';

import '../helpers/helpers.dart';

/// Battery: a [BackdropFilter] is only allowed where there is real detail
/// behind it.
///
/// Blur is a per-frame GPU pass that also invalidates whatever repaints
/// underneath, and a widget that appears once per list row pays it once per
/// row: the ten-card list is where this first showed up as foreground drain
/// (#75). The other half of the rule is that over a flat canvas or a smooth
/// gradient a blur *gives back the pixels it was given* — so it is not a
/// trade-off, it is pure cost.
///
/// Until now that rule lived in a doc comment on `NavisCard`, which is why a
/// `BackdropFilter(8)` sat unnoticed inside `DocumentStatusBadge` — one per
/// document row — and inside the app bar of every single screen. These tests
/// make the rule fail out loud.
///
/// The allow-list is asserted too, so this reads as the policy rather than as a
/// blanket ban: the map/photo overlays keep their blur, and a regression that
/// removed it would also be caught.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(buildTestAppWithScaffold(child));
    await tester.pump(const Duration(milliseconds: 300));
  }

  void expectNoBlur(String what) {
    expect(
      find.byType(BackdropFilter),
      findsNothing,
      reason: '$what is drawn once per row; a blur here is paid per row, '
          'and over the page canvas it returns the same pixels',
    );
  }

  group('content widgets never blur', () {
    testWidgets('NavisCard', (tester) async {
      await pump(tester, const NavisCard(child: Text('x')));
      expectNoBlur('NavisCard');
    });

    testWidgets('NavisRow inside NavisList', (tester) async {
      await pump(
        tester,
        const NavisList(
          title: 'Group',
          children: [
            NavisRow(title: 'One', value: '1'),
            NavisRow(title: 'Two', value: '2'),
          ],
        ),
      );
      expectNoBlur('NavisRow');
    });

    testWidgets('NavisMetric', (tester) async {
      await pump(
        tester,
        const NavisMetricGrid(
          children: [
            NavisMetric(value: '12', label: 'a'),
            NavisMetric(value: '34', label: 'b'),
          ],
        ),
      );
      expectNoBlur('NavisMetric');
    });

    testWidgets('NavisAlert', (tester) async {
      await pump(tester, const NavisAlert(message: 'nope'));
      expectNoBlur('NavisAlert');
    });

    testWidgets('NavisShimmer', (tester) async {
      await pump(tester, const NavisShimmer(itemCount: 4));
      expectNoBlur('NavisShimmer');
    });

    testWidgets('DocumentCard', (tester) async {
      await pump(tester, DocumentCard(document: makeDocument()));
      expectNoBlur('DocumentCard');
    });

    testWidgets('DocumentStatusBadge, expired and valid alike', (tester) async {
      // Expired is the interesting case: it is the one that also glows, and it
      // used to wrap the glow in a blur.
      await pump(
        tester,
        DocumentStatusBadge(
          expiryDate: DateTime.now().subtract(const Duration(days: 30)),
        ),
      );
      expectNoBlur('DocumentStatusBadge (expired)');

      await pump(
        tester,
        DocumentStatusBadge(
          expiryDate: DateTime.now().add(const Duration(days: 400)),
        ),
      );
      expectNoBlur('DocumentStatusBadge (valid)');
    });

    testWidgets('TripCard', (tester) async {
      await pump(tester, TripCard(trip: makeTrip()));
      expectNoBlur('TripCard');
    });
  });

  group('the app bar only blurs over media', () {
    testWidgets('plain app bar draws no BackdropFilter', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(appBar: NavisAppBar(title: 'T'), body: SizedBox()),
        ),
      );
      await tester.pump();

      expect(
        find.byType(BackdropFilter),
        findsNothing,
        reason: 'the canvas behind the bar is flat (light) or a smooth '
            'gradient (dark); blurring either returns the same pixels',
      );
    });

    testWidgets('overMedia app bar does blur', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            appBar: NavisAppBar(title: 'T', overMedia: true),
            body: SizedBox(),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byType(BackdropFilter),
        findsOneWidget,
        reason: 'over a map or a photograph the blur is what makes the bar '
            'legible, and there it earns its cost',
      );
    });
  });

  group('the auth screens blur nothing', () {
    testWidgets('the login logo is not blurred', (tester) async {
      // It wrapped a `BackdropFilter(12)` around `assets/icon/navis_icon.png`:
      // a blur over a static asset, so there was nothing behind it to reveal
      // and a filter pass to pay for — on the first screen of the app.
      await pump(tester, const NavisTextField(label: 'field'));
      expectNoBlur('an auth field');
    });
  });

  group('map and photo overlays keep their blur', () {
    testWidgets('GlassContainer blurs', (tester) async {
      await pump(tester, const GlassContainer(child: Text('overlay')));

      expect(
        find.byType(BackdropFilter),
        findsOneWidget,
        reason: 'GlassContainer exists for overlays on imagery — that is the '
            'one place a backdrop filter is the right tool',
      );
    });
  });
}
