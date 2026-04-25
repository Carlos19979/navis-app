import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';

class PositionIndicator extends StatelessWidget {
  const PositionIndicator({super.key, required this.position});

  final LatLng position;

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: [
        Marker(
          point: position,
          width: 28,
          height: 28,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cyan,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyan.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
