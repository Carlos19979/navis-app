import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/boat/presentation/screens/boat_detail_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';

import '../helpers/pumping.dart';

class BoatRobot {
  BoatRobot(this.tester);

  final WidgetTester tester;

  /// Empty-state CTA on a fresh account; also asserts the dashboard loaded.
  Future<void> expectEmptyDashboard() =>
      pumpUntilFound(tester, find.text('Add Boat'));

  Future<void> startAddBoat() async {
    await tapUntil(tester, _addBoatTrigger(), find.text('New Boat'));
  }

  /// On the Free plan at the boat limit, the add action opens the paywall
  /// instead of the form.
  Future<void> startAddBoatExpectingPaywall() async {
    await tapUntil(tester, _addBoatTrigger(), find.text('Navis Pro'));
  }

  Future<void> dismissPaywall() async {
    // Modal bottom sheet: tapping the barrier above it dismisses.
    await tester.tapAt(const Offset(200, 60));
    await pumpUntilGone(tester, find.text('Navis Pro'));
  }

  /// Empty dashboards offer the empty-state CTA; populated ones the FAB.
  Finder _addBoatTrigger() {
    final cta = find.text('Add Boat');
    if (cta.evaluate().isNotEmpty) return cta;
    return find.byType(FloatingActionButton);
  }

  /// The boat-detail hub's scrollable, for scoped lazy-sliver scrolling.
  Finder detailScrollable() => find.descendant(
        of: find.byType(BoatDetailScreen),
        matching: find.byType(Scrollable),
      );

  /// Opens the Share boat sheet from the detail hub and reads the invite
  /// code (the prominent cyan 26pt text — the only reliable handle).
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
  Future<void> joinByCode(String code) async {
    // Dialog-scoped: unscoped TextFields (e.g. the outgoing register form
    // during a route transition) would satisfy the finder prematurely.
    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tapUntil(tester, find.byTooltip('Join a boat'), dialogField);
    await pumpFor(tester, const Duration(milliseconds: 400));
    await pumpUntilFound(tester, dialogField);
    await tester.enterText(dialogField.first, code);
    await tester.pump(const Duration(milliseconds: 200));
    await tapUntilGone(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Join'),
      ),
      find.byType(AlertDialog),
    );
    await pumpFor(tester, const Duration(seconds: 1));
  }

  /// Deletes a boat from its detail screen (danger action + confirm dialog).
  /// The tile lives at the bottom of a lazy CustomScrollView — scroll first.
  Future<void> deleteBoat(String name) async {
    await openDetail(name);
    final tile = find.text('Delete Boat');
    await scrollTo(
      tester,
      tile,
      scrollable: find.descendant(
        of: find.byType(BoatDetailScreen),
        matching: find.byType(Scrollable),
      ),
    );
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
    await _enterField('Boat Name', name);
    await _enterField('Registration Number', registration);
    await _enterField('Length (m)', length);
    if (homePort != null) {
      await _enterField('Home Port (optional)', homePort);
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

  /// Opens the boat detail hub. Single-boat dashboards render a focus card
  /// with a 'Manage boat' link; multi-boat dashboards navigate by card tap.
  /// 'Details' (info section header) is the detail-only marker that renders
  /// above the fold — hub tiles further down are lazy sliver children.
  Future<void> openDetail(String name) async {
    final detailMarker = find.text('Details');
    final manage = find.text('Manage boat');
    await pumpFor(tester, const Duration(milliseconds: 400));
    if (manage.evaluate().isNotEmpty) {
      await tapUntil(tester, manage, detailMarker);
    } else {
      await tapUntil(tester, find.text(name), detailMarker);
    }
    await pumpFor(tester, const Duration(milliseconds: 400));
  }

  /// Taps a hub tile on the boat detail screen (e.g. 'Documents',
  /// 'Maintenance & expenses', 'Bookings') and waits for [appears]. Tiles
  /// low in the hub are lazy sliver children — scroll to build them.
  Future<void> openTile(String tile, Finder appears) async {
    final f = find.text(tile);
    await scrollTo(
      tester,
      f,
      scrollable: find.descendant(
        of: find.byType(BoatDetailScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tapUntil(tester, f, appears);
    await pumpFor(tester, const Duration(milliseconds: 400));
  }

  Future<void> _enterField(String label, String value) async {
    final field = find.widgetWithText(TextFormField, label);
    await pumpUntilFound(tester, field);
    await enterTextChecked(tester, field, value);
  }
}
