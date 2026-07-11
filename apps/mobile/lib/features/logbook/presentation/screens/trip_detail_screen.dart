import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/core/utils/distance_utils.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/charts/data/tile_provider.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripProvider(tripId));

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: NavisAppBar(
          title: AppLocalizations.of(context)!.tripDetails,
          showBack: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: AppLocalizations.of(context)!.shareTrip,
              onPressed: () => _shareTrip(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: AppLocalizations.of(context)!.editTrip,
              onPressed: () => context.push('/trips/$tripId/edit'),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outlined,
                color: AppColors.red,
              ),
              tooltip: AppLocalizations.of(context)!.deleteTrip,
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
        body: tripAsync.when(
          loading: () => const NavisLoading(),
          error: (error, stack) => NavisErrorWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(tripProvider(tripId)),
          ),
          data: (trip) {
            final trackPoints = trip.trackPoints ?? [];
            final hasTrack = trackPoints.isNotEmpty;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasTrack) ...[
                    _buildMapCard(context, trackPoints),
                    const SizedBox(height: 12),
                    const _SpeedLegend(),
                    const SizedBox(height: 16),
                  ],
                  _buildRouteCard(context, trip),
                  const SizedBox(height: 12),
                  _buildStatsCard(context, trip),
                  if (trip.engineHours != null ||
                      trip.fuelConsumedL != null) ...[
                    const SizedBox(height: 12),
                    _buildEngineCard(context, trip),
                  ],
                  if (trip.crewMembers != null &&
                      trip.crewMembers!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildCrewCard(context, trip),
                  ],
                  if (trip.notes != null && trip.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildNotesCard(context, trip),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMapCard(
    BuildContext context,
    List<TrackPoint> trackPoints,
  ) {
    return GestureDetector(
      onTap: () => _openFullScreenMap(context, trackPoints),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.glassBorderColor,
                  width: 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: RepaintBoundary(
                  child: SizedBox(
                    height: 220,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(
                          trackPoints.first.latitude,
                          trackPoints.first.longitude,
                        ),
                        initialZoom: 12,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        OpenSeaMapTileProvider.baseLayer,
                        PolylineLayer(
                          polylines: _buildSpeedPolylines(trackPoints),
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                trackPoints.first.latitude,
                                trackPoints.first.longitude,
                              ),
                              width: 14,
                              height: 14,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.green
                                          .withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Marker(
                              point: LatLng(
                                trackPoints.last.latitude,
                                trackPoints.last.longitude,
                              ),
                              width: 14,
                              height: 14,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          AppColors.red.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.fullscreen, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreenMap(
    BuildContext context,
    List<TrackPoint> trackPoints,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _TripMapFullScreen(
          trackPoints: trackPoints,
          polylines: _buildSpeedPolylines(trackPoints),
        ),
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, Trip trip) {
    return NavisCard(
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.flight_takeoff,
            label: AppLocalizations.of(context)!.departure,
            value:
                '${trip.departurePort}\n${NavisDateUtils.formatDateTime(trip.departureTime)}',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              height: 0.5,
              color: context.glassBorderColor,
            ),
          ),
          _DetailRow(
            icon: Icons.flight_land,
            label: AppLocalizations.of(context)!.arrival,
            value: trip.arrivalPort != null
                ? '${trip.arrivalPort}'
                    '${trip.arrivalTime != null ? '\n${NavisDateUtils.formatDateTime(trip.arrivalTime!)}' : ''}'
                : AppLocalizations.of(context)!.notRecorded,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, Trip trip) {
    return NavisCard(
      child: Row(
        children: [
          if (trip.distanceNm != null)
            Expanded(
              child: _StatBox(
                label: AppLocalizations.of(context)!.distance,
                value: DistanceUtils.formatDistance(
                  trip.distanceNm!,
                ),
                icon: Icons.straighten,
              ),
            ),
          if (trip.duration != null)
            Expanded(
              child: _StatBox(
                label: AppLocalizations.of(context)!.duration,
                value: NavisDateUtils.formatDuration(
                  trip.duration!,
                ),
                icon: Icons.schedule,
              ),
            ),
          if (trip.avgSpeedKnots != null)
            Expanded(
              child: _StatBox(
                label: AppLocalizations.of(context)!.avgSpeed,
                value: DistanceUtils.formatSpeed(
                  trip.avgSpeedKnots!,
                ),
                icon: Icons.speed,
              ),
            ),
          if (trip.maxSpeedKnots != null)
            Expanded(
              child: _StatBox(
                label: AppLocalizations.of(context)!.maxSpeed,
                value: DistanceUtils.formatSpeed(
                  trip.maxSpeedKnots!,
                ),
                icon: Icons.speed,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEngineCard(BuildContext context, Trip trip) {
    return NavisCard(
      child: Column(
        children: [
          if (trip.engineHours != null)
            _DetailRow(
              icon: Icons.engineering,
              label: AppLocalizations.of(context)!.engineHours,
              value: '${trip.engineHours!.toStringAsFixed(1)} h',
            ),
          if (trip.engineHours != null && trip.fuelConsumedL != null) ...[
            const SizedBox(height: 12),
            Container(
              height: 0.5,
              color: context.glassBorderColor,
            ),
            const SizedBox(height: 12),
          ],
          if (trip.fuelConsumedL != null)
            _DetailRow(
              icon: Icons.local_gas_station,
              label: AppLocalizations.of(context)!.fuelConsumed,
              value: '${trip.fuelConsumedL!.toStringAsFixed(1)} L',
            ),
        ],
      ),
    );
  }

  Widget _buildCrewCard(BuildContext context, Trip trip) {
    return NavisCard(
      child: _DetailRow(
        icon: Icons.group,
        label: AppLocalizations.of(context)!.crew,
        value: trip.crewMembers!.join(', '),
      ),
    );
  }

  Widget _buildNotesCard(BuildContext context, Trip trip) {
    return NavisCard(
      child: _DetailRow(
        icon: Icons.notes,
        label: AppLocalizations.of(context)!.notes,
        value: trip.notes!,
      ),
    );
  }

  List<Polyline> _buildSpeedPolylines(
    List<TrackPoint> trackPoints,
  ) {
    if (trackPoints.length < 2) return [];

    final polylines = <Polyline>[];
    for (int i = 0; i < trackPoints.length - 1; i++) {
      final speed = trackPoints[i].speedKnots ?? 0;
      final color = switch (speed) {
        < 3 => AppColors.cyan,
        < 6 => AppColors.green,
        < 12 => AppColors.amber,
        _ => AppColors.red,
      };

      polylines.add(
        Polyline(
          points: [
            LatLng(
              trackPoints[i].latitude,
              trackPoints[i].longitude,
            ),
            LatLng(
              trackPoints[i + 1].latitude,
              trackPoints[i + 1].longitude,
            ),
          ],
          color: color,
          strokeWidth: 3.5,
        ),
      );
    }
    return polylines;
  }

  String _summaryText(Trip trip) {
    final distance = trip.distanceNm != null
        ? '${trip.distanceNm!.toStringAsFixed(1)} NM'
        : '';
    final duration = trip.duration != null
        ? '${trip.duration!.inHours}h ${trip.duration!.inMinutes % 60}m'
        : '';
    return (StringBuffer()
          ..writeln('${trip.departurePort} \u2192 ${trip.arrivalPort ?? '?'}')
          ..writeln(trip.departureTime.toLocal().toString().substring(0, 16))
          ..writeln(
            [distance, duration].where((s) => s.isNotEmpty).join(' \u2022 '),
          ))
        .toString();
  }

  void _shareTrip(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.read(tripProvider(tripId));
    if (tripAsync case AsyncData(:final value)) {
      final trip = value;
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: context.dialogSurface,
        showDragHandle: true,
        builder: (sheetCtx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.link, color: AppColors.cyan),
                title: const Text('Compartir enlace'),
                subtitle: const Text('P\u00e1gina web con el mapa del viaje'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _shareLink(context, ref, trip);
                },
              ),
              ListTile(
                leading: const Icon(Icons.short_text, color: AppColors.cyan),
                title: const Text('Compartir resumen'),
                subtitle: const Text('Texto con los datos del viaje'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  Share.share('${_summaryText(trip)}\nHecho con Navis');
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _shareLink(
      BuildContext context, WidgetRef ref, Trip trip) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await ref.read(tripRepositoryProvider).shareTrip(trip.id);
      await Share.share('${_summaryText(trip)}\n$url');
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo crear el enlace')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await NavisConfirmDialog.show(
      context,
      title: l.deleteTrip,
      message: l.deleteTripConfirm,
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!confirmed) return;
    final trip = ref.read(tripProvider(tripId)).valueOrNull;
    try {
      final repo = ref.read(tripRepositoryProvider);
      await repo.deleteTrip(tripId);
      if (trip != null) {
        ref.invalidate(boatTripsProvider(trip.boatId));
      }
      ref.invalidate(tripProvider(tripId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.tripDeleted)),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.failedToDelete}: $e')),
        );
      }
    }
  }
}

class _SpeedLegend extends StatelessWidget {
  const _SpeedLegend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: AppColors.cyan, label: '<3 kt'),
        SizedBox(width: 12),
        _LegendDot(color: AppColors.green, label: '3-6 kt'),
        SizedBox(width: 12),
        _LegendDot(color: AppColors.amber, label: '6-12 kt'),
        SizedBox(width: 12),
        _LegendDot(color: AppColors.red, label: '>12 kt'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.txtSecondary,
              ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: context.glassBg,
            shape: BoxShape.circle,
            border: Border.all(
              color: context.glassBorderColor,
              width: 0.5,
            ),
          ),
          child: Icon(icon, size: 16, color: AppColors.cyan),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.txtSecondary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.cyan),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.cyan,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.txtSecondary,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

/// Full-screen, interactive view of a finished trip's track.
class _TripMapFullScreen extends StatelessWidget {
  const _TripMapFullScreen({
    required this.trackPoints,
    required this.polylines,
  });

  final List<TrackPoint> trackPoints;
  final List<Polyline> polylines;

  @override
  Widget build(BuildContext context) {
    final points = trackPoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(points),
                padding: const EdgeInsets.all(48),
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              OpenSeaMapTileProvider.baseLayer,
              OpenSeaMapTileProvider.seamarkLayer,
              PolylineLayer(polylines: polylines),
              MarkerLayer(
                markers: [
                  _endpointMarker(points.first, AppColors.green),
                  _endpointMarker(points.last, AppColors.red),
                ],
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: AppLocalizations.of(context)!.goBack,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Marker _endpointMarker(LatLng point, Color color) {
    return Marker(
      point: point,
      width: 16,
      height: 16,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6),
          ],
        ),
      ),
    );
  }
}
