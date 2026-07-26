import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/shared/widgets/navis_pulse_budget.dart';

class PositionIndicator extends StatelessWidget {
  const PositionIndicator({super.key, required this.position});

  final LatLng position;

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: [
        Marker(
          point: position,
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring: pulses a couple of times to draw the eye to the
              // boat, then settles into a static halo. Left on `repeat()` it
              // repainted over the map tiles and the blurred map overlays at
              // 60 fps for the whole session.
              RepaintBoundary(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.cyan.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                )
                    .animate(
                      onPlay: (controller) => controller.repeat(
                        reverse: true,
                        count: PulseBudget.reverseHalves(
                          PulseBudget.decorative,
                        ),
                      ),
                    )
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.2, 1.2),
                      duration: 1500.ms,
                      curve: Curves.easeInOut,
                    )
                    .fadeOut(
                      begin: 0.6,
                      duration: 1500.ms,
                      curve: Curves.easeInOut,
                    ),
              ),
              // Inner dot
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.cyan,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
