import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/ports/domain/entities/port.dart';
import 'package:navis_mobile/features/ports/presentation/widgets/port_info_sheet.dart';

class PortMarkersLayer extends StatelessWidget {
  const PortMarkersLayer({
    super.key,
    required this.ports,
    this.userPosition,
    this.onPortTap,
  });

  final List<Port> ports;
  final LatLng? userPosition;
  final ValueChanged<Port>? onPortTap;

  IconData _iconForType(PortType type) => switch (type) {
        PortType.marina => Icons.anchor,
        PortType.anchorage => Icons.water,
        PortType.fuel => Icons.local_gas_station,
        PortType.commercial => Icons.business,
        PortType.fishing => Icons.set_meal,
        PortType.other => Icons.location_on,
      };

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: ports.map((port) {
        final icon = _iconForType(port.portType);
        return Marker(
          point: LatLng(port.lat, port.lon),
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () {
              if (onPortTap != null) {
                onPortTap!(port);
              } else {
                showPortInfoSheet(
                  context,
                  port: port,
                  userPosition: userPosition,
                );
              }
            },
            child: Tooltip(
              message: port.name,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.cyan.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Icon(icon, color: AppColors.cyan, size: 18),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
