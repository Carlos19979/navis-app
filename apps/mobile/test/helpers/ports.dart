import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/features/ports/data/repositories/port_repository.dart';
import 'package:navis_mobile/features/ports/domain/entities/port.dart';
import 'package:navis_mobile/features/ports/presentation/providers/port_provider.dart';

/// A [PortRepository] that answers from a fixed list instead of the network.
///
/// The map screens drive their marker feed through a
/// `ViewportPortsController`, which holds the repository directly — so a map
/// test overrides [portRepositoryProvider] with one of these rather than
/// stubbing a provider per viewport.
class FakePortRepository extends PortRepository {
  FakePortRepository({this.ports = const [], this.error});

  /// Ports every query resolves with.
  final List<Port> ports;

  /// When set, every query throws this instead — for exercising the
  /// keep-what-is-drawn behaviour on a failed viewport.
  final Object? error;

  /// Bounding boxes requested so far, in order.
  final List<({double minLon, double minLat, double maxLon, double maxLat})>
      bboxRequests = [];

  /// Search queries requested so far, in order.
  final List<String> searchRequests = [];

  @override
  Future<({List<Port> ports, String? nextCursor})> getWithinBBox({
    required double minLon,
    required double minLat,
    required double maxLon,
    required double maxLat,
    String? cursor,
    int limit = 50,
  }) async {
    bboxRequests.add((
      minLon: minLon,
      minLat: minLat,
      maxLon: maxLon,
      maxLat: maxLat,
    ));
    if (error != null) throw error!;
    return (ports: ports, nextCursor: null);
  }

  @override
  Future<List<Port>> searchPorts({
    required String query,
    double? nearLat,
    double? nearLon,
    int limit = 50,
  }) async {
    searchRequests.add(query);
    if (error != null) throw error!;
    return ports;
  }

  @override
  Future<List<Port>> getNearby({
    required double lat,
    required double lon,
    double radiusKm = 50,
    int limit = 50,
  }) async {
    if (error != null) throw error!;
    return ports;
  }

  @override
  Future<Port> getById(String id) async {
    if (error != null) throw error!;
    return ports.firstWhere((p) => p.id == id);
  }
}

/// Overrides the ports repository with a fake serving [ports].
Override overridePorts({List<Port> ports = const [], Object? error}) {
  return portRepositoryProvider.overrideWithValue(
    FakePortRepository(ports: ports, error: error),
  );
}
