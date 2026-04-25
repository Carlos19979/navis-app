import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';

class MapControls extends StatelessWidget {
  const MapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onCenterGps,
    required this.onToggleLayers,
    required this.showSeamarks,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onCenterGps;
  final VoidCallback onToggleLayers;
  final bool showSeamarks;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ControlButton(
            icon: Icons.add,
            onPressed: onZoomIn,
          ),
          const SizedBox(height: 8),
          _ControlButton(
            icon: Icons.remove,
            onPressed: onZoomOut,
          ),
          const SizedBox(height: 16),
          _ControlButton(
            icon: Icons.my_location,
            onPressed: onCenterGps,
          ),
          const SizedBox(height: 8),
          _ControlButton(
            icon: showSeamarks ? Icons.layers : Icons.layers_outlined,
            onPressed: onToggleLayers,
            isActive: showSeamarks,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: isActive ? AppColors.cyan : AppColors.textPrimary,
          size: 22,
        ),
        constraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
      ),
    );
  }
}
