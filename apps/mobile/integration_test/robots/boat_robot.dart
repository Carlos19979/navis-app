import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/billing/presentation/paywall_sheet.dart';
import 'package:navis_mobile/features/boat/presentation/screens/today_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_text_field.dart';

import '../helpers/pumping.dart';
import 'nav_robot.dart';

class BoatRobot {
  BoatRobot(this.tester);

  final WidgetTester tester;

  /// Empty-state CTA on a fresh account; also asserts the dashboard loaded.
  Future<void> expectEmptyDashboard() =>
      pumpUntilFound(tester, find.text('Add boat'));

  Future<void> startAddBoat() async {
    await tapUntil(tester, _addBoatTrigger(), find.text('New Boat'));
  }

  /// On the Free plan at the boat limit, the add action opens the paywall
  /// instead of the form.
  ///
  /// Located by [paywallSheetKey], never by its heading: the heading names the
  /// tier(s) actually on offer ('Navis Pro' for a Pro-only gate, 'Navis Plus &
  /// Pro' when both apply), so matching text made the assertion depend on which
  /// packages the store returned.
  Future<void> startAddBoatExpectingPaywall() async {
    await tapUntil(tester, _addBoatTrigger(), _paywall());
  }

  Future<void> dismissPaywall() async {
    // Modal bottom sheet: tapping the barrier above it dismisses.
    await tester.tapAt(const Offset(200, 60));
    await pumpUntilGone(tester, _paywall());
  }

  Finder _paywall() => find.byKey(paywallSheetKey);

  /// Empty dashboards offer the empty-state CTA; populated ones the FAB.
  Finder _addBoatTrigger() {
    final cta = find.text('Add boat');
    if (cta.evaluate().isNotEmpty) return cta;
    return find.byType(FloatingActionButton);
  }

  /// Today's scrollable, by key.
  ///
  /// By key and not by type: Today nests scrollables (the photo strip, the
  /// picker sheet), and `find.byType(Scrollable).first` picked whichever the
  /// tree happened to build first.
  Finder detailScrollable() => find.byKey(todayScrollKey);

  /// Scrolls Today top to bottom and returns every label seen on the way.
  ///
  /// It is a lazy list: what scrolls off is disposed, so "the member sees their
  /// permissions AND 'Leave shared boat' at the bottom, and no owner-only row
  /// anywhere" cannot be asserted from one screenful. Scoped to TodayScreen so
  /// the nav pill's own labels are not smuggled in.
  Future<Set<String>> readDetailLabels({int drags = 8}) async {
    final labels = find.descendant(
      of: find.byType(TodayScreen),
      matching: find.byType(Text),
    );
    final seen = <String>{};
    void collect() {
      for (final element in labels.evaluate()) {
        final data = (element.widget as Text).data?.trim();
        if (data != null && data.isNotEmpty) seen.add(data);
      }
    }

    await pumpFor(tester, const Duration(milliseconds: 400));
    collect();
    for (var i = 0; i < drags; i++) {
      await tester.drag(
        detailScrollable().first,
        const Offset(0, -400),
        warnIfMissed: false,
      );
      await pumpFor(tester, const Duration(milliseconds: 400));
      collect();
    }
    return seen;
  }

  /// Opens the Share boat sheet from Today and reads the invite code (the
  /// prominent 26pt text — the only reliable handle).
  Future<String> readShareCode() async {
    final codeText = find.byWidgetPredicate(
      (w) => w is Text && w.style?.fontSize == 26,
    );
    await scrollTo(
      tester,
      find.text('Share boat'),
      scrollable: detailScrollable(),
    );
    await tapUntil(tester, find.text('Share boat'), codeText);
    final code = (tester.widget<Text>(codeText.first).data ?? '').trim();
    // Dismiss the sheet (tap the barrier above it).
    await tester.tapAt(const Offset(200, 60));
    await pumpFor(tester, const Duration(milliseconds: 600));
    return code;
  }

  /// Joins a boat by invite code from the dashboard app-bar action.
  ///
  /// The entry point is a `TextButton.icon` with a visible label (no tooltip),
  /// and the code is collected by the shared join-by-code **modal sheet** — not
  /// an AlertDialog. Both are located through the sheet's own widgets: its
  /// submit NavisButton, and the NavisTextField it owns (the only one on the
  /// dashboard).
  Future<void> joinByCode(String code) async {
    final submit = find.widgetWithText(NavisButton, 'Join');
    final sheetField = find.descendant(
      of: find.byType(NavisTextField),
      matching: find.byType(TextField),
    );
    await tapUntil(
      tester,
      find.widgetWithText(TextButton, 'Join a boat'),
      submit,
    );
    await pumpFor(tester, const Duration(milliseconds: 400));
    await pumpUntilFound(tester, sheetField);
    await tester.enterText(sheetField.last, code);
    await tester.pump(const Duration(milliseconds: 300));
    await tapUntilGone(tester, submit, submit);
    await pumpFor(tester, const Duration(seconds: 1));
  }

  /// Deletes a boat from its detail screen (danger action + confirm dialog).
  /// The tile lives at the bottom of a lazy CustomScrollView — scroll first.
  Future<void> deleteBoat(String name) async {
    await openDetail(name);
    final tile = find.text('Delete boat');
    await scrollTo(tester, tile, scrollable: detailScrollable());
    await tapUntil(tester, tile, find.text('Cancel'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tapUntilGone(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
      find.byType(AlertDialog),
    );
    await pumpFor(tester, const Duration(seconds: 1));
  }

  /// Fills the required fields (type dropdown keeps its default) and submits.
  /// Home port is genuinely optional (nullable end to end since migration
  /// 00033) — pass [homePort] to also exercise the with-port path.
  Future<void> createBoat({
    required String name,
    required String registration,
    String length = '9.5',
    String? homePort,
  }) async {
    await _enterField('Boat name', name);
    await _enterField('Registration number', registration);
    await _enterField('Length', length);
    if (homePort != null) {
      await _enterField('Home port', homePort);
    }
    // Dismiss the keyboard so the submit button is tappable, then require the
    // form to actually go away — a missed tap or validation error would
    // otherwise pass silently (field values don't show up as Text widgets).
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 300));
    final submit = find.widgetWithText(NavisButton, 'Create Boat');
    // Retry the tap: a submit that lands shows either navigation (form gone)
    // or an error/validation message; a missed tap shows neither.
    for (var attempt = 0; attempt < 3; attempt++) {
      await tester.ensureVisible(submit.first);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(submit.first);
      try {
        await pumpUntilGone(
          tester,
          find.text('New Boat'),
          timeout: const Duration(seconds: 10),
        );
        return;
      } on TestFailure {
        if (attempt == 2) rethrow;
      }
    }
  }

  Future<void> expectBoatOnDashboard(String name) =>
      pumpUntilFound(tester, find.text(name));

  /// Opens the boat detail hub by tapping the boat's card.
  ///
  /// One behaviour for every dashboard: the whole card navigates, with one boat
  /// or with several. The old single-boat 'Manage boat' link is gone — it was a
  /// corner link users had to hunt for.
  ///
  /// 'Details' (info section header) is the detail-only marker that renders
  /// above the fold — hub tiles further down are lazy sliver children.
  Future<void> openDetail(String name) async {
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tapUntil(tester, find.text(name), find.text('Details'));
    await pumpFor(tester, const Duration(milliseconds: 400));
  }

  /// Taps a hub tile on the boat detail screen and waits for [appears].
  ///
  /// The hub is now where everything about the boat lives: 'Documents',
  /// 'Logbook', 'Trip statistics', 'Maintenance & expenses', 'Cost
  /// intelligence', 'Bookings', 'Anchor watch', 'Export passport', 'Crew and
  /// permissions' (owner only), 'Share boat', 'Edit'/'Delete boat'. Tiles low in
  /// the hub are lazy sliver children — scroll to build them.
  Future<void> openTile(String tile, Finder appears) async {
    final f = find.text(tile);
    await scrollTo(
      tester,
      f,
      scrollable: detailScrollable(),
    );
    await tapUntil(tester, f, appears);
    await pumpFor(tester, const Duration(milliseconds: 400));
  }

  /// Returns to the detail hub from a screen opened by [openTile].
  ///
  /// The hub stays mounted underneath a pushed route, so its own markers
  /// ('Details') match even while the pushed screen is on top. "Are we back?" is
  /// therefore asserted by the pushed screen's [marker] going away.
  Future<void> backToHub(Finder marker) async {
    await NavRobot(tester).back();
    await pumpUntilGone(tester, marker);
    await pumpFor(tester, const Duration(milliseconds: 400));
  }

  /// Pops the detail hub back to the dashboard.
  ///
  /// The hub is pushed on the root navigator, above the bottom-nav shell, so the
  /// nav pill cannot be tapped while it is open: a journey that wants a tab has
  /// to come back here first.
  Future<void> closeDetail() async {
    await NavRobot(tester).back();
    await pumpUntilGone(tester, find.text('Details'));
    await pumpFor(tester, const Duration(milliseconds: 400));
  }

  Future<void> _enterField(String label, String value) async {
    final field = find.widgetWithText(TextFormField, label);
    await pumpUntilFound(tester, field);
    await enterTextChecked(tester, field, value);
  }
}
