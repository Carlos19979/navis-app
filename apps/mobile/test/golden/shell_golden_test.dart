@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/shared/widgets/navis_gradient_fab.dart';
import 'package:navis_mobile/shared/widgets/navis_scaffold.dart';

import '../helpers/helpers.dart';
import 'golden_harness.dart';

/// A tab screen **with the floating nav pill on screen**, which is the only way
/// to judge where its FAB sits.
///
/// Every other golden pumps the branch alone, so the pill is missing and a tab
/// screen's FAB looks stranded in mid-air — which is exactly how the misplaced
/// lift went unnoticed: the scaffold raised the FAB by `navClearance` (sized for
/// the worst case, a notched phone) on every device, leaving 50 px of air above
/// the pill on a phone without a home indicator.
void main() {
  setUpAll(loadTestFonts);

  for (final brightness in Brightness.values) {
    testWidgets('tab shell — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        _FakeShell(),
        brightness: brightness,
        settle: false,
      );
      await expectLater(
        find.byType(_FakeShell),
        matchesGoldenFile(goldenPath('shell', brightness)),
      );
    });
  }

  testWidgets('the FAB clears the pill without floating above it',
      (tester) async {
    // Measured, both ways round: on a phone with no home indicator and on one
    // with a 34 px inset.
    for (final inset in [0.0, 34.0]) {
      await tester.pumpWidget(
        buildTestApp(
          MediaQuery(
            data: MediaQueryData(
              padding: EdgeInsets.only(bottom: inset),
              size: const Size(390, 844),
            ),
            child: _FakeShell(),
          ),
        ),
      );
      await pumpFrames(tester, frames: 4);

      final screen = tester.getSize(find.byType(_FakeShell)).height;
      final fab = tester.getRect(find.byType(NavisGradientFab));
      final pillTop = screen - Dimens.navPillTop(inset);

      expect(
        fab.bottom,
        lessThanOrEqualTo(pillTop),
        reason: 'inset $inset: the FAB must not sit on the pill',
      );
      expect(
        pillTop - fab.bottom,
        lessThan(Dimens.spaceXl),
        reason: 'inset $inset: ${pillTop - fab.bottom} px of air above the '
            'pill — the FAB reads as stranded mid-screen',
      );
    }
  });
}

/// A tab screen the way the shell hosts one: the branch body, and the pill
/// drawn over it at its real height.
class _FakeShell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).padding.bottom;
    return Stack(
      children: [
        NavisScaffold(
          title: 'Comunidad',
          safeAreaBottom: false,
          floatingActionButton: NavisGradientFab(
            icon: Icons.add,
            onPressed: () {},
            tooltip: 'Crear club',
          ),
          body: const SizedBox.expand(),
        ),
        Positioned(
          left: Dimens.spaceXl,
          right: Dimens.spaceXl,
          bottom: Dimens.navPillInset(inset),
          child: Container(
            height: Dimens.bottomNavHeight,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(Dimens.radiusXxl),
            ),
          ),
        ),
      ],
    );
  }
}
