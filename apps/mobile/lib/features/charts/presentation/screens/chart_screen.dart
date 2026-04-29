import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/charts/data/tile_provider.dart';
import 'package:navis_mobile/features/charts/presentation/providers/chart_provider.dart';
import 'package:navis_mobile/features/charts/presentation/widgets/map_controls.dart';
import 'package:navis_mobile/features/charts/presentation/widgets/position_indicator.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';

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
    final boatsAsync = ref.watch(boatsProvider);

    return Scaffold(
      body: Stack(
        children: [
          RepaintBoundary(
            child: FlutterMap(
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
                if (boatsAsync case AsyncData(:final value))
                  MarkerLayer(
                    markers: [
                      for (final boat in value)
                        if (boat.homePortLat != null &&
                            boat.homePortLon != null)
                          Marker(
                            point: LatLng(
                              boat.homePortLat!,
                              boat.homePortLon!,
                            ),
                            width: 48,
                            height: 48,
                            child: Tooltip(
                              message: '${boat.name}'
                                  ' \u2014 '
                                  '${boat.homePort ?? "Home port"}',
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.navy.withValues(alpha: 0.7),
                                  border: Border.all(
                                    color:
                                        AppColors.cyan.withValues(alpha: 0.6),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          AppColors.cyan.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.anchor,
                                    color: AppColors.cyan,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                if (mapState.showTracks)
                  if (boatsAsync case AsyncData(:final value))
                    _TripTracksLayer(boats: value),
              ],
            ),
          ),

          // Glass GPS status overlay at top
          if (_currentPosition != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.glassBorder,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_currentPosition!.latitude.toStringAsFixed(4)}, '
                          '${_currentPosition!.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'z${mapState.zoom.toStringAsFixed(0)}',
                          style: TextStyle(
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
            onToggleTracks: () {
              ref.read(chartProvider.notifier).toggleTracks();
            },
            showTracks: mapState.showTracks,
          ),
        ],
      ),
    );
  }
}

class _TripTracksLayer extends ConsumerWidget {
  const _TripTracksLayer({required this.boats});

  final List<Boat> boats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final polylines = <Polyline>[];
    for (final boat in boats) {
      final tripsAsync = ref.watch(boatTripsProvider(boat.id));
      if (tripsAsync case AsyncData(:final value)) {
        for (final trip in value) {
          final points = trip.trackPoints;
          if (points != null && points.length >= 2) {
            polylines.add(
              Polyline(
                points: [
                  for (final pt in points) LatLng(pt.latitude, pt.longitude),
                ],
                strokeWidth: 3,
                color: AppColors.cyan.withValues(alpha: 0.7),
              ),
            );
          }
        }
      }
    }

    if (polylines.isEmpty) return const SizedBox.shrink();

    return PolylineLayer(polylines: polylines);
  }
}
