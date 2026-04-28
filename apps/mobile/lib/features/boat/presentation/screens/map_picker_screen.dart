import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/charts/data/tile_provider.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _selectedPoint;

  static const _defaultCenter = LatLng(39.57, 2.63);

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null &&
        widget.initialLongitude != null) {
      _selectedPoint = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _selectedPoint ?? _defaultCenter;

    return Scaffold(
      appBar: NavisAppBar(
        title: 'Select Home Port',
        showBack: true,
        actions: [
          if (_selectedPoint != null)
            IconButton(
              onPressed: () =>
                  Navigator.of(context).pop(_selectedPoint),
              tooltip: 'Confirm location',
              icon: const Icon(Icons.check, color: AppColors.green),
            ),
        ],
      ),
      body: Stack(
        children: [
          RepaintBoundary(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: _selectedPoint != null ? 14 : 6,
                onTap: (_, point) {
                  setState(() => _selectedPoint = point);
                },
              ),
              children: [
                OpenSeaMapTileProvider.baseLayer,
                OpenSeaMapTileProvider.seamarkLayer,
                if (_selectedPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedPoint!,
                        width: 48,
                        height: 48,
                        child: const Icon(
                          Icons.anchor,
                          color: AppColors.cyan,
                          size: 40,
                          semanticLabel: 'Selected location',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              children: [
                if (_selectedPoint != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppColors.cyan,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_selectedPoint!.latitude.toStringAsFixed(4)}, '
                            '${_selectedPoint!.longitude.toStringAsFixed(4)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium,
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () => Navigator.of(context)
                                .pop(_selectedPoint),
                            child: const Text('Confirm'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.touch_app,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tap the map to set your home port',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color:
                                      AppColors.textSecondary,
                                ),
                          ),
                        ],
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
