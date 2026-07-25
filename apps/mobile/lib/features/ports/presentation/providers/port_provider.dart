import 'package:flutter/foundation.dart';
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

/// Below this zoom the visible area is too large to fetch ports for; the map
/// shows none rather than requesting a near-global slice (the server also
/// rejects boxes wider than 90°).
const double kMinPortsZoom = 7;

/// Grid, in degrees, the visible bounds snap to so small pans reuse the same
/// cache key instead of refetching on every frame.
const double _bboxSnapGrid = 0.1;

/// Hard cap on markers fetched for one viewport, across paginated requests.
const int _maxVisiblePorts = 300;

/// Max pages walked per viewport (the server caps each page at 50).
const int _maxPortPages = 6;

/// Snaps raw visible bounds outward to [_bboxSnapGrid] so panning within a
/// grid cell keeps the same provider key (debounce-by-grid), and clamps to
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

/// Ports inside the snapped viewport bounding box. Walks a bounded number of
/// cursor pages and caps the total markers so a dense area never floods the
/// map; autoDispose releases stale boxes as the user pans away.
final visiblePortsProvider =
    FutureProvider.autoDispose.family<List<Port>, PortsBBox>(
  (ref, bbox) async {
    final repository = ref.watch(portRepositoryProvider);
    final ports = <Port>[];
    String? cursor;

    for (var page = 0; page < _maxPortPages; page++) {
      final result = await repository.getWithinBBox(
        minLon: bbox.minLon,
        minLat: bbox.minLat,
        maxLon: bbox.maxLon,
        maxLat: bbox.maxLat,
        cursor: cursor,
      );
      ports.addAll(result.ports);
      cursor = result.nextCursor;

      if (cursor == null) break;
      if (ports.length >= _maxVisiblePorts) {
        debugPrint(
          '[ports] viewport truncated at ${ports.length} markers '
          '(more available for this area)',
        );
        break;
      }
    }

    if (ports.length > _maxVisiblePorts) {
      return ports.sublist(0, _maxVisiblePorts);
    }
    return ports;
  },
);

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
