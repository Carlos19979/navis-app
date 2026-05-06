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

final allPortsProvider = FutureProvider<List<Port>>((ref) async {
  final repository = ref.watch(portRepositoryProvider);
  return repository.getNearby(
    lat: 39.5,
    lon: 2.6,
    radiusKm: 5000,
    limit: 500,
  );
});

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
