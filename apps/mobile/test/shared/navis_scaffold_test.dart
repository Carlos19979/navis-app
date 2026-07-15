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

  testWidgets(
      'tab screens (safeAreaBottom: false) lift the FAB above the '
      'floating bottom nav', (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(subject(safeAreaBottom: false));
    await pumpScreen(tester);

    final fabBottom = tester.getRect(find.byType(FloatingActionButton)).bottom;
    final screenHeight = tester.getSize(find.byType(Scaffold).first).height;
    // The nav bar overlay occupies navClearance from the bottom; the FAB
    // must clear it (16 = the FAB's own default margin, kept by Scaffold).
    expect(
      screenHeight - fabBottom,
      greaterThanOrEqualTo(Dimens.navClearance - 16),
      reason: 'FAB sits under the floating bottom nav (bug #6)',
    );
  });

  testWidgets('pushed screens (safeAreaBottom: true) keep the default FAB '
      'position', (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(subject(safeAreaBottom: true));
    await pumpScreen(tester);

    final fabBottom = tester.getRect(find.byType(FloatingActionButton)).bottom;
    final screenHeight = tester.getSize(find.byType(Scaffold).first).height;
    expect(screenHeight - fabBottom, lessThan(Dimens.navClearance - 16));
  });
}
