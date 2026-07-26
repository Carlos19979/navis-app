import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/features/ports/data/repositories/port_repository.dart';
import 'package:navis_mobile/features/ports/domain/entities/port.dart';

final portRepositoryProvider = Provider<PortRepository>((ref) {
  return PortRepository();
});

final nearbyPortsProvider = FutureProvider.family<List<Port>,
    ({double lat, double lon, double radiusKm})>(
  (ref, params) async {
    final repository = ref.watch(portRepositoryProvider);
    return repository.getNearby(
      lat: params.lat,
      lon: params.lon,
      radiusKm: params.radiusKm,
    );
  },
);

/// Geographic bounding box for a viewport ports query, in WGS84 degrees.
typedef PortsBBox = ({
  double minLon,
  double minLat,
  double maxLon,
  double maxLat,
});

/// Below this zoom a viewport holds more ports than one page can carry, so the
/// markers would be an arbitrary (alphabetical) slice of a dense area rather
/// than a useful picture — and far enough out the server rejects the span.
///
/// Zooming out past it stops *fetching*; the markers already drawn stay put
/// (see `ViewportPortsController`), so zooming back in never shows an empty map.
/// Keep it low enough that a regional view — what the map and the home-port
/// picker open on — is inside it.
const double kMinPortsZoom = 6;

/// Grid, in degrees, the visible bounds snap to so small pans reuse the same
/// viewport instead of refetching on every frame. Roughly 11 km.
const double _bboxSnapGrid = 0.1;

/// Snaps raw visible bounds outward to [_bboxSnapGrid] so panning within a
/// grid cell keeps the same viewport (debounce-by-grid), and clamps to
/// valid WGS84 ranges.
PortsBBox snapBBox({
  required double minLon,
  required double minLat,
  required double maxLon,
  required double maxLat,
}) {
  double floor(double v) => (v / _bboxSnapGrid).floorToDouble() * _bboxSnapGrid;
  double ceil(double v) => (v / _bboxSnapGrid).ceilToDouble() * _bboxSnapGrid;
  return (
    minLon: floor(minLon).clamp(-180.0, 180.0).toDouble(),
    minLat: floor(minLat).clamp(-90.0, 90.0).toDouble(),
    maxLon: ceil(maxLon).clamp(-180.0, 180.0).toDouble(),
    maxLat: ceil(maxLat).clamp(-90.0, 90.0).toDouble(),
  );
}

/// Arguments for [portSearchProvider]: the (already trimmed/debounced) query
/// and an optional reference point to order results by distance.
typedef PortSearchArgs = ({String query, double? nearLat, double? nearLon});

/// Server-side port name search. Returns an empty list for blank/too-short
/// queries without hitting the network. autoDispose so each picker releases
/// its results on close.
final portSearchProvider =
    FutureProvider.autoDispose.family<List<Port>, PortSearchArgs>(
  (ref, args) async {
    final query = args.query.trim();
    if (query.length < 2) return const [];
    final repository = ref.watch(portRepositoryProvider);
    return repository.searchPorts(
      query: query,
      nearLat: args.nearLat,
      nearLon: args.nearLon,
    );
  },
);

({double lat, double lon, double radiusKm}) roundedPortParams({
  required double lat,
  required double lon,
  required double radiusKm,
}) {
  return (
    lat: (lat * 10).roundToDouble() / 10,
    lon: (lon * 10).roundToDouble() / 10,
    radiusKm: radiusKm,
  );
}
