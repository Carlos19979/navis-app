import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
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
      markers: [
        for (final port in ports)
          Marker(
            point: LatLng(port.lat, port.lon),
            width: 36,
            height: 36,
            child: _PortMarker(
              icon: _iconForType(port.portType),
              label: port.name,
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
            ),
          ),
      ],
    );
  }
}

/// A single port pin.
///
/// Kept deliberately cheap: a viewport can hold hundreds of these, and they are
/// laid out again on every camera frame. So no [Tooltip] (each one is a
/// stateful overlay host plus a long-press recognizer — and a hover tooltip is
/// no use on a touch map, tapping opens the info sheet) and no blurred
/// [BoxShadow] (a per-marker blur pass is the single most expensive thing you
/// can put in a map layer). The name still reaches assistive tech via
/// [Semantics].
class _PortMarker extends StatelessWidget {
  const _PortMarker({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.navy.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: context.accent.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Icon(icon, color: context.accent, size: 18),
        ),
      ),
    );
  }
}
