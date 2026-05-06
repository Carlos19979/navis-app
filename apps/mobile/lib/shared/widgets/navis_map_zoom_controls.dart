import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

class NavisMapZoomControls extends StatelessWidget {
  const NavisMapZoomControls({
    super.key,
    required this.mapController,
    this.bottom = 140,
    this.right = 16,
  });

  final MapController mapController;
  final double bottom;
  final double right;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Positioned(
      right: right,
      bottom: bottom,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ZoomButton(
                  icon: Icons.add,
                  tooltip: l.zoomIn,
                  onTap: () => mapController.move(
                    mapController.camera.center,
                    mapController.camera.zoom + 1,
                  ),
                ),
                Container(
                  height: 0.5,
                  width: 28,
                  color: AppColors.glassBorder,
                ),
                _ZoomButton(
                  icon: Icons.remove,
                  tooltip: l.zoomOut,
                  onTap: () => mapController.move(
                    mapController.camera.center,
                    mapController.camera.zoom - 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: AppColors.textPrimary, size: 22),
        ),
      ),
    );
  }
}
