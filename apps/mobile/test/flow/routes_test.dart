import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/app/routes.dart';

/// The router declares path *patterns*; `Routes` declares *builders*. Nothing
/// stops the two from drifting — except this.
///
/// It checks both directions, and the second one is the point:
///
///  * every builder produces a path some route can match — no builder that
///    navigates nowhere;
///  * every route is produced by some builder — no screen that exists in the
///    router and can only be reached by hand-writing its path, which is how a
///    screen ends up unreachable without anyone noticing.
///
/// Reading the router's source rather than its object graph is deliberate:
/// `GoRouter`'s configuration is not public API, and the thing worth pinning is
/// the declaration, not the runtime.
void main() {
  /// The fixed destinations, by the name the router refers to them with.
  ///
  /// Keyed by name so the last test can compare this set against the
  /// `path: Routes.<name>` entries the router actually declares — that is what
  /// closes the loop for the half that is no longer a literal.
  final fixed = <String, String>{
    'login': Routes.login,
    'register': Routes.register,
    'checkEmail': Routes.checkEmail,
    'resetPassword': Routes.resetPassword,
    'today': Routes.today,
    'charts': Routes.charts,
    'weather': Routes.weather,
    'community': Routes.community,
    'profile': Routes.profile,
    'newBoat': Routes.newBoat,
    'newGroup': Routes.newGroup,
    'settings': Routes.settings,
    'offlineCharts': Routes.offlineCharts,
    'notifications': Routes.notifications,
  };

  /// The parameterised destinations, with sample arguments. These are the ones
  /// that can drift, because the router spells their pattern out by hand.
  ///
  /// Add a line when you add a builder. If you forget, the third test fails —
  /// that is the safety net, not this list.
  final built = <String>[
    Routes.boat('b1'),
    Routes.boatEdit('b1'),
    Routes.boatDocuments('b1'),
    Routes.newDocument('b1'),
    Routes.boatMaintenance('b1'),
    Routes.boatReadiness('b1'),
    Routes.boatCosts('b1'),
    Routes.boatBookings('b1'),
    Routes.boatAnchor('b1'),
    Routes.boatTrips('b1'),
    Routes.boatStats('b1'),
    Routes.boatPrecheck('b1'),
    Routes.boatPrecheck('b1', port: 'Palma'),
    Routes.boatRecord('b1'),
    Routes.boatRecord('b1', tripId: 't1', regatta: true, autostart: true),
    Routes.document('d1'),
    Routes.documentEdit('d1', boatId: 'b1'),
    Routes.documentEdit('d1', boatId: 'b1', renew: true),
    Routes.trip('t1'),
    Routes.tripEdit('t1'),
    Routes.tripChecklist('t1'),
    Routes.tripChecklist('t1', groupId: 'g1'),
    Routes.group('g1'),
    Routes.groupSchedule('g1'),
    Routes.event('e1'),
    Routes.eventStartRegatta('e1'),
    Routes.regatta('r1'),
  ];

  /// The `path:` **patterns** still written as literals in the router — the
  /// parameterised ones, which is what `GoRoute` needs.
  ///
  /// The fixed paths (`/login`, `/boats`, `/settings`…) now read `path:
  /// Routes.login` straight from the same constant the callers use, so there is
  /// nothing left for them to drift from. What can still drift is a pattern
  /// like `/boats/:id/costs` against the builder that fills it in, and that is
  /// what the two tests below pin.
  final routerSource = File('lib/app/router.dart').readAsStringSync();

  final patterns = () {
    final found = RegExp(r"path: '([^']+)'")
        .allMatches(routerSource)
        .map((m) => m.group(1)!)
        .toList();
    found.sort((a, b) => b.split('/').length.compareTo(a.split('/').length));
    return found;
  }();

  /// The names in `path: Routes.<name>`.
  final declaredNames = RegExp(r'path: Routes\.(\w+)')
      .allMatches(routerSource)
      .map((m) => m.group(1)!)
      .toSet();

  RegExp asRegExp(String pattern) => RegExp(
        '^${pattern.replaceAll(RegExp(r':[A-Za-z]+'), r'[^/]+')}\$',
      );

  String? matchOf(String location) {
    final path = Uri.parse(location).path;
    for (final pattern in patterns) {
      if (asRegExp(pattern).hasMatch(path)) return pattern;
    }
    return null;
  }

  test('the router still declares parameterised patterns as literals', () {
    expect(patterns, isNotEmpty);
    expect(patterns, contains('/boats/:id'));
  });

  test('every parameterised builder lands on a declared pattern', () {
    final dangling = built.where((s) => matchOf(s) == null).toList();
    expect(
      dangling,
      isEmpty,
      reason: 'these builders produce a path no GoRoute matches, so they would '
          'fall through to the error page: $dangling',
    );
  });

  test('every declared pattern is produced by a builder', () {
    final produced = built.map(matchOf).whereType<String>().toSet();
    final unreachable = patterns.where((p) => !produced.contains(p)).toList();
    expect(
      unreachable,
      isEmpty,
      reason: 'these routes exist but no builder produces them, so reaching '
          'them means hand-writing the path — which is how a screen becomes '
          'unreachable without anyone noticing: $unreachable',
    );
  });

  test('the fixed routes the router declares all exist in Routes', () {
    // The router says `path: Routes.login`; this checks there is no name in
    // the router that this file does not know about, and none here that the
    // router never declares.
    expect(declaredNames.difference(fixed.keys.toSet()), isEmpty,
        reason: 'the router declares a Routes name this test does not cover');
    expect(fixed.keys.toSet().difference(declaredNames), isEmpty,
        reason: 'this test lists a fixed route the router never declares');
    expect(fixed.values.every((v) => v.startsWith('/')), isTrue);
  });

  group('query parameters', () {
    test('are omitted when empty rather than left dangling', () {
      expect(Routes.boatPrecheck('b1'), '/boats/b1/precheck');
      expect(Routes.boatRecord('b1'), '/boats/b1/record');
      expect(Routes.boatPrecheck('b1', port: ''), '/boats/b1/precheck');
    });

    test('carry the flags the destination screens read', () {
      expect(
        Routes.boatRecord('b1', tripId: 't1', regatta: true, autostart: true),
        '/boats/b1/record?tripId=t1&regatta=true&autostart=true',
      );
      expect(
        Routes.documentEdit('d1', boatId: 'b1', renew: true),
        '/documents/d1/edit?boatId=b1&renew=true',
      );
    });

    test('encode a port name with spaces', () {
      expect(
        Routes.boatPrecheck('b1', port: 'Port de Sóller'),
        contains('port=Port%20de%20S%C3%B3ller'),
      );
    });
  });
}
