/// Every destination in the app, in one place.
///
/// Until now a route was a string literal written by hand at the call site —
/// spread across 31 files, with the query parameters assembled inline. Two
/// consequences, both of which bit:
///
///  * **Reachability could not be checked.** Working out whether a screen was
///    orphaned meant grepping for a pattern that half the call sites did not
///    match, because they built the path from a variable.
///  * **Renaming a path meant finding every literal.** `CLAUDE.md` has always
///    said routes belong in `app/router.dart` as path constants; there were
///    zero.
///
/// The router declares the *patterns* (`/boats/:id`); this declares the
/// *builders* (`Routes.boat('b1')`). `test/flow/routes_test.dart` asserts the two
/// stay in step in both directions — no builder without a route, no route
/// without a builder.
abstract final class Routes {
  // ── Access ──────────────────────────────────────────────────────────────
  static const login = '/login';
  static const register = '/register';
  static const checkEmail = '/check-email';
  static const resetPassword = '/reset-password';

  // ── Tabs ────────────────────────────────────────────────────────────────
  /// Today. Still `/boats` because it is a notification deep-link target and
  /// the redirect destination after sign-in, delete and leave.
  static const today = '/boats';
  static const charts = '/charts';
  static const weather = '/weather';
  static const community = '/community';
  static const profile = '/profile';

  // ── The boat ────────────────────────────────────────────────────────────
  static const newBoat = '/boats/new';

  /// Today, scoped to a specific boat: makes it the active one.
  static String boat(String id) => '/boats/$id';
  static String boatEdit(String id) => '/boats/$id/edit';
  static String boatDocuments(String id) => '/boats/$id/documents';
  static String newDocument(String id) => '/boats/$id/documents/new';
  static String boatMaintenance(String id) => '/boats/$id/maintenance';
  static String boatReadiness(String id) => '/boats/$id/readiness';
  static String boatCosts(String id) => '/boats/$id/costs';
  static String boatBookings(String id) => '/boats/$id/bookings';
  static String boatAnchor(String id) => '/boats/$id/anchor';
  static String boatTrips(String id) => '/boats/$id/trips';
  static String boatStats(String id) => '/boats/$id/stats';

  /// The optional pre-departure checklist.
  static String boatPrecheck(String id, {String? port}) =>
      _withQuery('/boats/$id/precheck', {'port': port});

  /// The recording map.
  ///
  /// [autostart] is what the checklist passes on its way out; [tripId] and
  /// [regatta] are what a regatta start passes so the recorder attaches to the
  /// trip that already exists.
  static String boatRecord(
    String id, {
    String? tripId,
    bool regatta = false,
    bool autostart = false,
    String? port,
  }) =>
      _withQuery('/boats/$id/record', {
        'tripId': tripId,
        'regatta': regatta ? 'true' : null,
        'autostart': autostart ? 'true' : null,
        'port': port,
      });

  // ── Documents ───────────────────────────────────────────────────────────
  static String document(String id) => '/documents/$id';

  /// [renew] opens the form pre-filled to extend the expiry rather than to
  /// correct the document.
  static String documentEdit(
    String id, {
    required String boatId,
    bool renew = false,
  }) =>
      _withQuery('/documents/$id/edit', {
        'boatId': boatId,
        'renew': renew ? 'true' : null,
      });

  // ── Trips ───────────────────────────────────────────────────────────────
  static String trip(String id) => '/trips/$id';
  static String tripEdit(String id) => '/trips/$id/edit';
  static String tripChecklist(String id, {String? groupId}) =>
      _withQuery('/trips/$id/checklist', {'groupId': groupId});

  // ── Community ───────────────────────────────────────────────────────────
  static const newGroup = '/groups/new';
  static String group(String id) => '/groups/$id';
  static String groupSchedule(String id) => '/groups/$id/schedule';
  static String event(String id) => '/events/$id';
  static String eventStartRegatta(String id) => '/events/$id/start-regatta';
  static String regatta(String id) => '/regattas/$id';

  // ── Account and the rest ────────────────────────────────────────────────
  static const settings = '/settings';
  static const offlineCharts = '/charts/offline';
  static const notifications = '/notifications';

  /// Appends the entries whose value is non-null and non-empty. Assembling this
  /// by hand at the call site is how `'?port='` with an empty value ended up in
  /// the trip recorder's URL.
  ///
  /// `encodeComponent`, not `encodeQueryComponent`: the latter writes a space as
  /// `+`, and while `Uri.queryParameters` decodes both, `%20` is what every
  /// existing caller produced and what the checklist's test pins.
  static String _withQuery(String path, Map<String, String?> params) {
    final parts = <String>[
      for (final entry in params.entries)
        if (entry.value != null && entry.value!.isNotEmpty)
          '${entry.key}=${Uri.encodeComponent(entry.value!)}',
    ];
    return parts.isEmpty ? path : '$path?${parts.join('&')}';
  }
}
