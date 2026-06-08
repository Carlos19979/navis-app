import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/ports/presentation/providers/port_provider.dart';
import 'package:navis_mobile/features/ports/presentation/widgets/port_selector_field.dart';

/// Loads ports near the boat's home port and shows the shared
/// [PortSelectorField] so the user can choose a departure port.
class DeparturePortPicker extends ConsumerWidget {
  const DeparturePortPicker({
    required this.boat,
    required this.onChanged,
    super.key,
  });

  final Boat boat;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lat = boat.homePortLat;
    final lon = boat.homePortLon;

    // No home-port coordinates: fall back to a map-only selector.
    if (lat == null || lon == null) {
      return PortSelectorField(
        label: '',
        icon: Icons.anchor,
        ports: const [],
        initialName: boat.homePort,
        mapTitle: 'Puerto de salida',
        onChanged: onChanged,
      );
    }

    final params = roundedPortParams(lat: lat, lon: lon, radiusKm: 100);
    final portsAsync = ref.watch(nearbyPortsProvider(params));

    return portsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: AppColors.cyan)),
      ),
      error: (_, __) => PortSelectorField(
        label: '',
        icon: Icons.anchor,
        ports: const [],
        refLat: lat,
        refLon: lon,
        initialName: boat.homePort,
        mapTitle: 'Puerto de salida',
        onChanged: onChanged,
      ),
      data: (ports) => PortSelectorField(
        label: '',
        icon: Icons.anchor,
        ports: ports,
        refLat: lat,
        refLon: lon,
        initialName: boat.homePort,
        mapTitle: 'Puerto de salida',
        onChanged: onChanged,
      ),
    );
  }
}
