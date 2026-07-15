import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';

import '../helpers/bootstrap.dart';
import '../helpers/pumping.dart';
import '../robots/nav_robot.dart';

/// J06 — Charts & Weather: structural asserts only. Both screens depend on
/// live upstreams (OpenSeaMap tiles, Open-Meteo via the API), so the checks
/// are "renders with the fake GPS position, no error state" rather than
/// data-exact.
void j06ChartsWeather() {
  testWidgets('j06 charts and weather render with fake GPS', (tester) async {
    await bootstrapApp(tester);
    await ensureSignedIn();
    await pumpFor(tester, const Duration(seconds: 1));
    final nav = NavRobot(tester);

    // Chart tab: the map renders (fake position grants permission), no
    // location-denied banner, no error widget.
    await nav.chart();
    await pumpFor(tester, const Duration(seconds: 2));
    await pumpUntilFound(tester, find.byType(FlutterMap));
    expect(find.byType(NavisErrorWidget), findsNothing);

    // Weather tab: either real data (a temperature) or the error/retry
    // state — a dead upstream must not fail the suite, a broken screen must.
    await nav.weather();
    await pumpFor(tester, const Duration(seconds: 3));
    final hasTemp =
        find.textContaining(RegExp('-?\\d+°')).evaluate().isNotEmpty;
    final hasError = find.byType(NavisErrorWidget).evaluate().isNotEmpty;
    expect(hasTemp || hasError, isTrue,
        reason: 'weather shows neither data nor its error state');

    await nav.home();
  });
}
