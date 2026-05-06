import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/charts/data/tile_provider.dart';
import 'package:navis_mobile/features/ports/presentation/providers/port_provider.dart';
import 'package:navis_mobile/features/ports/presentation/widgets/port_markers_layer.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_map_zoom_controls.dart';

class MapPickerResult {
  const MapPickerResult({
    required this.point,
    this.name,
  });

  final LatLng point;
  final String? name;
}

class MapPickerScreen extends ConsumerStatefulWidget {
  const MapPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.title,
    this.showNameField = false,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final String? title;
  final bool showNameField;

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  LatLng? _selectedPoint;
  final _nameCtrl = TextEditingController();
  final _mapController = MapController();

  static const _defaultCenter = LatLng(39.57, 2.63);

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPoint = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_selectedPoint == null) return;
    final name = _nameCtrl.text.trim();
    Navigator.of(context).pop(MapPickerResult(
      point: _selectedPoint!,
      name: name.isNotEmpty ? name : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final center = _selectedPoint ?? _defaultCenter;

    final canConfirm = _selectedPoint != null &&
        (!widget.showNameField || _nameCtrl.text.trim().isNotEmpty);

    return Scaffold(
      appBar: NavisAppBar(
        title: widget.title ?? l.selectHomePort,
        showBack: true,
        actions: [
          if (_selectedPoint != null)
            IconButton(
              onPressed: canConfirm ? _confirm : null,
              tooltip: l.confirmLocation,
              icon: Icon(
                Icons.check,
                color: canConfirm ? AppColors.green : AppColors.textSecondary,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          RepaintBoundary(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: _selectedPoint != null ? 14 : 6,
                onTap: (_, point) {
                  setState(() {
                    _selectedPoint = point;
                    _nameCtrl.clear();
                  });
                },
              ),
              children: [
                OpenSeaMapTileProvider.baseLayer,
                OpenSeaMapTileProvider.seamarkLayer,
                if (ref.watch(allPortsProvider) case AsyncData(:final value))
                  PortMarkersLayer(
                    ports: value,
                    onPortTap: (port) {
                      setState(() {
                        _selectedPoint = LatLng(port.lat, port.lon);
                        _nameCtrl.text = port.name;
                      });
                    },
                  ),
                if (_selectedPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedPoint!,
                        width: 52,
                        height: 52,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.navy.withValues(alpha: 0.6),
                            border: Border.all(
                              color: AppColors.cyan.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.cyan.withValues(alpha: 0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.anchor,
                            color: AppColors.cyan,
                            size: 28,
                            semanticLabel: l.selectLocation,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          NavisMapZoomControls(mapController: _mapController),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              children: [
                if (_selectedPoint != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.navy.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.glassBorder,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.cyan.withValues(alpha: 0.15),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: AppColors.cyan,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${_selectedPoint!.latitude.toStringAsFixed(4)}, '
                                '${_selectedPoint!.longitude.toStringAsFixed(4)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!widget.showNameField)
                              NavisButton(
                                label: l.confirm,
                                compact: true,
                                onPressed: _confirm,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_selectedPoint != null && widget.showNameField) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.navy.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.glassBorder,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameCtrl,
                                style: Theme.of(context).textTheme.bodyMedium,
                                decoration: InputDecoration(
                                  hintText: l.portNameHint,
                                  prefixIcon:
                                      const Icon(Icons.anchor, size: 18),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                                textCapitalization: TextCapitalization.words,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_nameCtrl.text.trim().isNotEmpty)
                              NavisButton(
                                label: l.confirm,
                                compact: true,
                                onPressed: _confirm,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (_selectedPoint == null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.navy.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.glassBorder,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.touch_app,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.6),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.showNameField
                                  ? l.tapMapToSelect
                                  : l.tapMapToSetHomePort,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
