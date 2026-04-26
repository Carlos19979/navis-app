import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/features/charts/data/tile_provider.dart';
import 'package:navis_mobile/features/charts/presentation/providers/chart_provider.dart';
import 'package:navis_mobile/features/charts/presentation/widgets/map_controls.dart';
import 'package:navis_mobile/features/charts/presentation/widgets/position_indicator.dart';

class ChartScreen extends ConsumerStatefulWidget {
  const ChartScreen({super.key});

  @override
  ConsumerState<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends ConsumerState<ChartScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentPosition();
  }

  Future<void> _getCurrentPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
    } on Exception {
      // Location not available; use default center
    }
  }

  void _centerOnGps() {
    if (_currentPosition != null) {
      ref.read(chartProvider.notifier).centerOnPosition(_currentPosition!);
      _mapController.move(_currentPosition!, 14);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(chartProvider);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapState.center,
              initialZoom: mapState.zoom,
              minZoom: 3,
              maxZoom: 18,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  ref.read(chartProvider.notifier).setCenter(position.center);
                  ref.read(chartProvider.notifier).setZoom(position.zoom);
                }
              },
            ),
            children: [
              OpenSeaMapTileProvider.baseLayer,
              if (mapState.showSeamarks) OpenSeaMapTileProvider.seamarkLayer,
              if (_currentPosition != null && mapState.showPosition)
                PositionIndicator(position: _currentPosition!),
            ],
          ),
          MapControls(
            onZoomIn: () {
              ref.read(chartProvider.notifier).zoomIn();
              _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom + 1,
              );
            },
            onZoomOut: () {
              ref.read(chartProvider.notifier).zoomOut();
              _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom - 1,
              );
            },
            onCenterGps: _centerOnGps,
            onToggleLayers: () {
              ref.read(chartProvider.notifier).toggleSeamarks();
            },
            showSeamarks: mapState.showSeamarks,
          ),
        ],
      ),
    );
  }
}
