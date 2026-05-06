import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

class MapControls extends StatelessWidget {
  const MapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onCenterGps,
    required this.onToggleLayers,
    required this.showSeamarks,
    this.onToggleTracks,
    this.showTracks = false,
    this.onTogglePorts,
    this.showPorts = false,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onCenterGps;
  final VoidCallback onToggleLayers;
  final bool showSeamarks;
  final VoidCallback? onToggleTracks;
  final bool showTracks;
  final VoidCallback? onTogglePorts;
  final bool showPorts;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 120,
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Builder(builder: (context) {
              final l = AppLocalizations.of(context)!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ControlButton(
                    icon: Icons.add,
                    tooltip: l.zoomIn,
                    onPressed: onZoomIn,
                  ),
                  _buildDivider(),
                  _ControlButton(
                    icon: Icons.remove,
                    tooltip: l.zoomOut,
                    onPressed: onZoomOut,
                  ),
                  _buildDivider(),
                  _ControlButton(
                    icon: Icons.my_location,
                    tooltip: l.centerOnGps,
                    onPressed: onCenterGps,
                  ),
                  _buildDivider(),
                  _ControlButton(
                    icon: showSeamarks ? Icons.layers : Icons.layers_outlined,
                    tooltip: l.toggleSeamarks,
                    onPressed: onToggleLayers,
                    isActive: showSeamarks,
                  ),
                  if (onTogglePorts != null) ...[
                    _buildDivider(),
                    _ControlButton(
                      icon: Icons.anchor,
                      tooltip: l.togglePorts,
                      onPressed: onTogglePorts!,
                      isActive: showPorts,
                    ),
                  ],
                  if (onToggleTracks != null) ...[
                    _buildDivider(),
                    _ControlButton(
                      icon: Icons.route,
                      tooltip: l.toggleTripTracks,
                      onPressed: onToggleTracks!,
                      isActive: showTracks,
                    ),
                  ],
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 0.5,
      width: 28,
      color: AppColors.glassBorder,
    );
  }
}

class _ControlButton extends StatefulWidget {
  const _ControlButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool isActive;

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: Tooltip(
        message: widget.tooltip ?? '',
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 48,
            height: 48,
            decoration: widget.isActive
                ? BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyan.withValues(alpha: 0.25),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  )
                : null,
            child: Icon(
              widget.icon,
              color: widget.isActive ? AppColors.cyan : AppColors.textPrimary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
