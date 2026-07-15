// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/charts/presentation/screens/chart_screen.dart';
import 'package:navis_mobile/features/ports/presentation/providers/port_provider.dart';

import '../../helpers/helpers.dart';

class _FakeBoatsNotifier extends AsyncNotifier<List<Boat>>
    implements BoatsNotifier {
  @override
  Future<List<Boat>> build() async => [makeBoat()];
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<Boat> createBoat(Boat boat) async => boat;
  @override
  Future<void> updateBoat(Boat boat) async {}
  @override
  Future<void> deleteBoat(String id) async {}
}

/// Spike: ChartScreen (flutter_map + geolocator) IS pumpable in widget tests.
///
/// Two things must be tolerated:
///  - Tile fetches: the map's CachedTileProvider resolves tiles through
///    cached_network_image, whose flutter_cache_manager backend hits
///    path_provider/HTTP; in tests that surfaces MissingPluginException and
///    image-load errors through FlutterError. They are cosmetic here, so a
///    scoped FlutterError.onError filter swallows only those.
///  - flutter_animate/tile fade timers: use pumpScreen + drain, never
///    pumpAndSettle.
void main() {
  testWidgets('ChartScreen renders the map with GPS permission granted',
      (tester) async {
    setPhoneSize(tester);
    installFakeGeo();

    // Scoped filter: ignore tile/network-image plumbing errors only.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exceptionAsString();
      const tolerated = [
        'MissingPluginException',
        'HTTP request failed',
        'NetworkImage',
        'CachedNetworkImageProvider',
        'HttpException',
        'SocketException',
        'Failed host lookup',
        'Connection refused',
        'Connection closed',
        'Couldn\'t download or retrieve file',
        'HttpExceptionWithStatus',
      ];
      if (tolerated.any(message.contains)) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(
      buildTestApp(
        const ChartScreen(),
        overrides: [
          boatsProvider.overrideWith(_FakeBoatsNotifier.new),
          allPortsProvider.overrideWith((ref) async => []),
        ],
      ),
    );
    await pumpScreen(tester);

    expect(find.byType(ChartScreen), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);

    // Dispose the map to cancel tile-loading/fade timers before teardown.
    await drain(tester);
  });
}
