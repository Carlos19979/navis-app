import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/charts/data/tile_provider.dart';
import 'package:navis_mobile/features/charts/presentation/providers/chart_provider.dart';
import 'package:navis_mobile/features/charts/presentation/providers/offline_charts_provider.dart';
import 'package:navis_mobile/features/charts/presentation/widgets/map_controls.dart';
import 'package:navis_mobile/features/charts/presentation/widgets/offline_chart_banner.dart';
import 'package:navis_mobile/features/charts/presentation/widgets/offline_charts_sheet.dart';
import 'package:navis_mobile/features/charts/presentation/widgets/position_indicator.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/ports/domain/entities/port.dart';
import 'package:navis_mobile/features/ports/presentation/controllers/viewport_ports_controller.dart';
import 'package:navis_mobile/features/ports/presentation/providers/port_provider.dart';
import 'package:navis_mobile/features/ports/presentation/widgets/port_info_sheet.dart';
import 'package:navis_mobile/features/ports/presentation/widgets/port_markers_layer.dart';

class ChartScreen extends ConsumerStatefulWidget {
  const ChartScreen({super.key});

  @override
  ConsumerState<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends ConsumerState<ChartScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  bool _locationDenied = false;

  /// Viewport ports feed. Owns its own debounce and memo, and publishes the
  /// markers as a listenable so panning repaints the marker layer only — never
  /// the whole screen (see [ViewportPortsController]).
  late final ViewportPortsController _ports;

  /// Live camera zoom, whole steps only — the granularity the readout and the
  /// "zoom in for ports" hint actually show, so a pan notifies at most once per
  /// zoom step instead of once per frame.
  final ValueNotifier<double> _liveZoom = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    final state = ref.read(chartProvider);
    _liveZoom.value = state.zoom.roundToDouble();
    _ports = ViewportPortsController(
      repository: ref.read(portRepositoryProvider),
      enabled: state.showPorts,
    );
    _getCurrentPosition();
  }

  @override
  void dispose() {
    _ports.dispose();
    _liveZoom.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationDenied = true);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _locationDenied = false;
      });
    } on Exception {
      // GPS unavailable (services off / timeout): surface a banner instead of
      // silently centering on the default position.
      if (mounted) setState(() => _locationDenied = true);
    }
  }

  /// Feeds the camera to the ports controller and the zoom readout. Called on
  /// every frame of a pan, so everything here is either a cheap comparison or
  /// debounced downstream — no provider writes, no setState.
  void _onCameraChanged(MapCamera camera) {
    final bounds = camera.visibleBounds;
    _ports.onCameraChanged(
      west: bounds.west,
      south: bounds.south,
      east: bounds.east,
      north: bounds.north,
      zoom: camera.zoom,
    );
    final stepped = camera.zoom.roundToDouble();
    if (_liveZoom.value != stepped) _liveZoom.value = stepped;
  }

  /// Persists the resting camera so reopening the tab returns to it. Only the
  /// settled events land here — never the per-frame move stream.
  void _onMapEvent(MapEvent event) {
    final settled = switch (event) {
      MapEventMoveEnd() => true,
      MapEventFlingAnimationEnd() => true,
      MapEventDoubleTapZoomEnd() => true,
      MapEventRotateEnd() => true,
      MapEventScrollWheelZoom() => true,
      // A programmatic move (zoom buttons, centre-on-GPS) is already a single
      // discrete jump, so it settles immediately.
      MapEventMove(source: MapEventSource.mapController) => true,
      _ => false,
    };
    if (!settled) return;
    ref
        .read(chartProvider.notifier)
        .settleCamera(event.camera.center, event.camera.zoom);
  }

  void _centerOnGps() {
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, 14);
    }
  }

  /// Offers the chart currently on screen for offline download. Reads the
  /// camera at tap time rather than tracking bounds per frame — what the user
  /// means by "this area" is whatever they are looking at now.
  Future<void> _openOfflineCharts() async {
    final bounds = _mapController.camera.visibleBounds;
    await showOfflineChartsSheet(
      context,
      box: (
        west: bounds.west,
        south: bounds.south,
        east: bounds.east,
        north: bounds.north,
      ),
    );
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    final target = (camera.zoom + delta).clamp(3.0, 18.0);
    if (target == camera.zoom) return;
    _mapController.move(camera.center, target);
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(chartProvider);
    final boatsAsync = ref.watch(boatsProvider);
    // Offline: clamp the tile layers to the deepest zoom actually on disk, so
    // zooming in upscales stored tiles instead of going blank.
    final offlineZoom = ref.watch(offlineChartZoomProvider);
    final downloading = ref.watch(chartDownloadProvider).isRunning;

    // Keep the ports layer in step with its toggle. ref.listen (not a build-time
    // call) so the controller is never mutated mid-build.
    ref.listen<bool>(
      chartProvider.select((s) => s.showPorts),
      (_, next) => _ports.setEnabled(next),
    );

    return Scaffold(
      body: Stack(
        children: [
          RepaintBoundary(
            child: ColoredBox(
              color: OpenSeaMapTileProvider.waterBackground,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: mapState.center,
                  initialZoom: mapState.zoom,
                  minZoom: 3,
                  maxZoom: 18,
                  // Seed the feed as soon as the map is laid out, so ports show
                  // on the initial view without waiting for a pan.
                  onMapReady: () => _onCameraChanged(_mapController.camera),
                  onPositionChanged: (position, _) =>
                      _onCameraChanged(position),
                  onMapEvent: _onMapEvent,
                ),
                children: [
                  OpenSeaMapTileProvider.baseLayer(maxNativeZoom: offlineZoom),
                  if (mapState.showSeamarks)
                    OpenSeaMapTileProvider.seamarkLayer(
                      maxNativeZoom: offlineZoom,
                    ),
                  _ViewportPortMarkers(
                    ports: _ports,
                    userPosition: _currentPosition,
                  ),
                  if (_currentPosition != null && mapState.showPosition)
                    PositionIndicator(position: _currentPosition!),
                  if (boatsAsync case AsyncData(:final value))
                    _HomePortMarkers(
                      boats: value,
                      ports: _ports,
                      userPosition: _currentPosition,
                    ),
                  if (mapState.showTracks)
                    if (boatsAsync case AsyncData(:final value))
                      _TripTracksLayer(boats: value),
                ],
              ),
            ),
          ),

          // What the chart under the boat actually is when the signal drops.
          Positioned(
            top: MediaQuery.of(context).padding.top + 54,
            left: 16,
            right: 16,
            child: const Align(
              alignment: Alignment.centerLeft,
              child: OfflineChartBanner(),
            ),
          ),

          // GPS unavailable: a glass banner with an open-settings action,
          // instead of silently sitting on the default center.
          if (_locationDenied && _currentPosition == null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
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
                      color: context.caution.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.caution.withValues(alpha: 0.4),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_off,
                            size: 16, color: context.caution),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.locationUnavailable,
                            style: TextStyle(
                                color: context.txtPrimary, fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: Geolocator.openLocationSettings,
                          child: Text(
                            AppLocalizations.of(context)!.openSettings,
                            style: TextStyle(color: context.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                          decoration: BoxDecoration(
                            color: context.positive,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_currentPosition!.latitude.toStringAsFixed(4)}, '
                          '${_currentPosition!.longitude.toStringAsFixed(4)}',
                          style: TextStyle(
                            color: context.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Listens to the live zoom directly, so a pinch
                        // repaints this label and nothing else.
                        ValueListenableBuilder<double>(
                          valueListenable: _liveZoom,
                          builder: (context, zoom, _) => Text(
                            'z${zoom.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: context.inkMuted.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Zoomed too far out to fetch a viewport: say so rather than leaving
          // the user wondering. Whatever was already loaded stays drawn.
          if (mapState.showPorts)
            ValueListenableBuilder<double>(
              valueListenable: _liveZoom,
              builder: (context, zoom, _) {
                if (zoom >= kMinPortsZoom) return const SizedBox.shrink();
                return Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
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
                              Icon(Icons.zoom_in,
                                  size: 16, color: context.accent),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context)!.portsZoomInHint,
                                style: TextStyle(
                                    color: context.txtPrimary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          MapControls(
            onZoomIn: () => _zoomBy(1),
            onZoomOut: () => _zoomBy(-1),
            onCenterGps: _centerOnGps,
            onToggleLayers: () {
              ref.read(chartProvider.notifier).toggleSeamarks();
            },
            showSeamarks: mapState.showSeamarks,
            onTogglePorts: () {
              ref.read(chartProvider.notifier).togglePorts();
            },
            showPorts: mapState.showPorts,
            onDownloadCharts: _openOfflineCharts,
            isDownloadingCharts: downloading,
          ),
        ],
      ),
    );
  }
}

/// The ports marker layer, wired to the viewport feed. Rebuilding is scoped to
/// this widget so new markers never rebuild the map screen around them.
class _ViewportPortMarkers extends StatelessWidget {
  const _ViewportPortMarkers({required this.ports, this.userPosition});

  final ViewportPortsController ports;
  final LatLng? userPosition;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Port>>(
      valueListenable: ports,
      builder: (context, value, _) {
        if (value.isEmpty) return const SizedBox.shrink();
        return PortMarkersLayer(ports: value, userPosition: userPosition);
      },
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
                color: context.accent.withValues(alpha: 0.7),
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

class _HomePortMarkers extends StatelessWidget {
  const _HomePortMarkers({
    required this.boats,
    required this.ports,
    this.userPosition,
  });

  final List<Boat> boats;

  /// Read on tap only, to look up the port a home-port pin sits on. Not
  /// listened to: these pins come from the boats, so a new viewport must not
  /// rebuild them.
  final ViewportPortsController ports;
  final LatLng? userPosition;

  Port? _findMatchingPort(double lat, double lon) {
    for (final port in ports.value) {
      final dLat = (port.lat - lat).abs();
      final dLon = (port.lon - lon).abs();
      if (dLat < 0.01 && dLon < 0.01) return port;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: [
        for (final boat in boats)
          if (boat.homePortLat != null && boat.homePortLon != null)
            Marker(
              point: LatLng(boat.homePortLat!, boat.homePortLon!),
              width: 48,
              height: 48,
              child: GestureDetector(
                onTap: () {
                  final port = _findMatchingPort(
                    boat.homePortLat!,
                    boat.homePortLon!,
                  );
                  if (port != null) {
                    showPortInfoSheet(
                      context,
                      port: port,
                      userPosition: userPosition,
                    );
                  }
                },
                child: Tooltip(
                  message: '${boat.name}'
                      ' \u2014 '
                      '${boat.homePort ?? "Home port"}',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.navy.withValues(alpha: 0.85),
                      border: Border.all(
                        color: context.caution.withValues(alpha: 0.8),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.caution.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.sailing,
                        color: context.caution,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
