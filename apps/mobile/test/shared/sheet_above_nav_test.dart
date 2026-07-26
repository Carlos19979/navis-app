import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/shared/widgets/join_by_code_sheet.dart';

import '../helpers/helpers.dart';

/// Modal bottom sheets must open on the ROOT navigator.
///
/// The app's bottom-nav pill lives in the shell Scaffold, *outside* the
/// per-tab branch navigators (see NavisBottomNav). A sheet pushed on a branch
/// navigator therefore renders inside the shell's body, and the floating pill
/// paints over its footer — which is how a sheet's buttons ended up hidden
/// behind the nav bar.
///
/// `showModalBottomSheet` defaults `useRootNavigator` to **false** (unlike
/// `showDialog`, which defaults to true), so every sheet has to opt in.
void main() {
  const branchKey = Key('branch-navigator');
  const navBarKey = Key('bottom-nav-pill');

  /// A miniature of the app's shell: a Scaffold owning the nav bar, whose body
  /// is a nested navigator for the tab content.
  Widget buildShell({required WidgetBuilder screen}) {
    return buildTestApp(
      Scaffold(
        extendBody: true,
        bottomNavigationBar: const SizedBox(
          key: navBarKey,
          height: 64,
        ),
        body: Navigator(
          key: branchKey,
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            builder: screen,
          ),
        ),
      ),
    );
  }

  testWidgets('a sheet opened from a tab is not trapped under the nav bar',
      (tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(
      buildShell(
        screen: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showJoinByCodeSheet(
              context,
              title: 'Join a club',
              description: 'Ask an admin for the code.',
            ),
            child: const Text('open sheet'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    final sheet = find.text('Join a club');
    expect(sheet, findsOneWidget);

    // The sheet must live OUTSIDE the branch navigator's subtree; inside it,
    // the nav bar would paint on top.
    expect(
      find.descendant(of: find.byKey(branchKey), matching: sheet),
      findsNothing,
      reason: 'sheet is on the branch navigator, so the nav bar covers it',
    );

    await drain(tester);
  });
}
