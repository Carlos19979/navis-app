import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/boat/presentation/widgets/permission_gate.dart';

import '../helpers/pumping.dart';
import 'boat_robot.dart';

/// Shared-boat permissions, both sides of the fence: the member who is blocked
/// and the owner who unblocks them.
///
/// Every string here is the English l10n value (bootstrap pins locale `en`).
/// They are the *user-visible* wording on purpose — the whole point of the
/// feature is that the reason is spelled out, so a test that matched keys or
/// widget types would not notice a padlock with nothing to read.
class PermissionsRobot {
  PermissionsRobot(this.tester);

  final WidgetTester tester;

  /// The reasons a [BlockedActionCard] can carry — one per flag the API
  /// enforces on its write paths (trips, documents, maintenance, expenses).
  static const recordTripsBlocked = 'You cannot record trips on this boat.';
  static const viewDocumentsBlocked = "You cannot see this boat's documents.";
  static const manageDocumentsBlocked =
      "You cannot add or edit this boat's documents.";
  static const manageMaintenanceBlocked =
      "You cannot manage this boat's maintenance.";
  static const manageExpensesBlocked =
      "You cannot manage this boat's expenses.";

  /// Row labels of the member's own 'What you can do' card, and of the owner's
  /// per-member toggles — the same five areas from both sides.
  static const recordTrips = 'Record trips';
  static const viewDocuments = 'View documents';
  static const manageDocuments = 'Manage documents';
  static const manageMaintenance = 'Manage maintenance';
  static const manageExpenses = 'Manage expenses';

  /// The owner-facing crew sheet, located by its explainer: its title ('Crew
  /// and permissions') is also the label of the hub tile that opens it, so the
  /// title alone cannot tell "sheet open" from "tile on screen".
  static const crewSheet = 'Everyone who joined with your code. Grant each of '
      'them only what they need.';

  /// What the crew list said after a successful join before the fix — the
  /// members provider was never invalidated, so the owner had nobody to grant
  /// anything to.
  static const nobodyShared = "You haven't shared with anyone yet.";

  /// The padlock card carrying [reason].
  ///
  /// Doubles as the `appears` finder for a tap that is *expected* to land on a
  /// block instead of on the action, e.g.
  /// `boat.openTile('Maintenance & expenses', perms.blocked(...))`.
  Finder blocked(String reason) => find.descendant(
        of: find.byType(BlockedActionCard),
        matching: find.text(reason),
      );

  Future<void> expectBlocked(String reason) =>
      pumpUntilFound(tester, blocked(reason));

  void expectNotBlocked(String reason) => expect(blocked(reason), findsNothing);

  /// Asserts the member's 'What you can do' row for [label] shows the tick.
  Future<void> expectGranted(String label) =>
      _expectRowIcon(label, Icons.check_circle_rounded);

  /// Asserts the same row shows the padlock instead.
  Future<void> expectWithheld(String label) =>
      _expectRowIcon(label, Icons.lock_outline_rounded);

  /// Owner: opens 'Crew and permissions' from the boat-detail hub. Owner-only
  /// by design — a member has no such tile, which is asserted from the journey
  /// against the hub's full label set.
  Future<void> openCrew() async {
    await BoatRobot(tester)
        .openTile('Crew and permissions', find.text(crewSheet));
    await pumpFor(tester, const Duration(milliseconds: 600));
  }

  /// Owner: the member who joined by code is listed, and the empty state is
  /// gone (see [nobodyShared]).
  Future<void> expectMember(String name) async {
    await pumpUntilFound(tester, find.text(name));
    expect(find.text(nobodyShared), findsNothing);
  }

  /// Owner: flips one permission on for [member] and waits until the server
  /// has answered — the tile's subtitle counts what is granted, so
  /// [expectSummary] ('1 permission') only appears once the toggle stuck.
  ///
  /// Each member is an ExpansionTile: tap the name to reveal the toggles.
  Future<void> grant(
    String member,
    String permission, {
    required String expectSummary,
  }) async {
    final toggle = find.widgetWithText(SwitchListTile, permission);
    await tapUntil(tester, find.text(member), toggle);
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tester.tap(toggle.first, warnIfMissed: false);
    await pumpUntilFound(tester, find.text(expectSummary));
    await pumpFor(tester, const Duration(milliseconds: 600));
  }

  /// Dismisses the crew sheet by tapping the barrier above it.
  Future<void> closeCrew() async {
    await tester.tapAt(const Offset(200, 40));
    await pumpUntilGone(tester, find.text(crewSheet));
    await pumpFor(tester, const Duration(milliseconds: 400));
  }

  Future<void> _expectRowIcon(String label, IconData icon) async {
    await pumpUntilFound(tester, find.text(label));
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (_rowHasIcon(label, icon)) return;
    }
    throw TestFailure(
      'permissions: the "$label" row never showed $icon '
      '(granted = check_circle_rounded, withheld = lock_outline_rounded)',
    );
  }

  /// A permission row is `Icon + Text` inside a Row, so the icon is reached by
  /// walking up from the label to its closest Row and back down.
  ///
  /// Matching the icon globally would not do: the padlock also belongs to every
  /// [BlockedActionCard] on screen, and the tick to other status widgets.
  bool _rowHasIcon(String label, IconData icon) {
    for (final labelElement in find.text(label).evaluate()) {
      Element? closestRow;
      labelElement.visitAncestorElements((ancestor) {
        if (ancestor.widget is Row) {
          closestRow = ancestor;
          return false;
        }
        return true;
      });
      final row = closestRow;
      if (row == null) continue;
      var found = false;
      void visit(Element element) {
        final widget = element.widget;
        if (widget is Icon && widget.icon == icon) found = true;
        element.visitChildren(visit);
      }

      row.visitChildren(visit);
      if (found) return true;
    }
    return false;
  }
}
