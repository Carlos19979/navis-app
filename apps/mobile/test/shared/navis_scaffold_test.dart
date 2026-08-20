import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/shared/widgets/navis_scaffold.dart';

import '../helpers/helpers.dart';

void main() {
  Widget subject({required bool safeAreaBottom}) => buildTestApp(
        NavisScaffold(
          title: 'T',
          safeAreaBottom: safeAreaBottom,
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            child: const Icon(Icons.add),
          ),
          body: const SizedBox.expand(),
        ),
      );

  testWidgets('a tab screen rests its FAB on the nav pill, not above it',
      (tester) async {
    // Two-sided on purpose. The old version of this test asserted only the
    // lower bound — «at least navClearance», which is the worst-case token for
    // a notched phone — so it *pinned the bug*: on a phone with no home
    // indicator the FAB sat 50 px above the pill and read as stranded in
    // mid-screen, and the test was green about it.
    for (final inset in [0.0, 34.0]) {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(bottom: inset)),
          child: subject(safeAreaBottom: false),
        ),
      );
      await pumpScreen(tester);

      final fabBottom =
          tester.getRect(find.byType(FloatingActionButton)).bottom;
      final screenHeight = tester.getSize(find.byType(Scaffold).first).height;
      final gap = (screenHeight - fabBottom) - Dimens.navPillTop(inset);

      expect(
        gap,
        greaterThanOrEqualTo(0),
        reason: 'inset $inset: the FAB overlaps the nav pill, so its taps land '
            'on the rightmost nav item',
      );
      expect(
        gap,
        lessThan(Dimens.spaceXl),
        reason: 'inset $inset: $gap px of air between the FAB and the pill',
      );
    }
  });

  testWidgets('pushed screens keep the default FAB position', (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(subject(safeAreaBottom: true));
    await pumpScreen(tester);

    final fabBottom = tester.getRect(find.byType(FloatingActionButton)).bottom;
    final screenHeight = tester.getSize(find.byType(Scaffold).first).height;
    expect(screenHeight - fabBottom, lessThan(Dimens.navPillTop(0)));
  });

  testWidgets('the app bar carries no profile shortcut', (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(subject(safeAreaBottom: true));
    await pumpScreen(tester);

    // Every NavisScaffold screen is pushed and already has a back button;
    // Profile is a bottom-nav tab, so the shortcut was pure duplication.
    expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
  });
}
