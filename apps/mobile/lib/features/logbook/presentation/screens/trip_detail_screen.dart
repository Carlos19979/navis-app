import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/distance_utils.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/charts/data/tile_provider.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
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
          title: 'Trip Details',
          showBack: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share trip',
              onPressed: () => _shareTrip(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit trip',
              onPressed: () => context.push('/trips/$tripId/edit'),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outlined,
                color: AppColors.red,
              ),
              tooltip: 'Delete trip',
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
                  if (trip.notes != null &&
                      trip.notes!.isNotEmpty) ...[
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.glassBorder,
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
                    polylines:
                        _buildSpeedPolylines(trackPoints),
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
                                color: AppColors.red
                                    .withValues(alpha: 0.4),
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
    );
  }

  Widget _buildRouteCard(BuildContext context, Trip trip) {
    return NavisCard(
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.flight_takeoff,
            label: 'Departure',
            value:
                '${trip.departurePort}\n${NavisDateUtils.formatDateTime(trip.departureTime)}',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              height: 0.5,
              color: AppColors.glassBorder,
            ),
          ),
          _DetailRow(
            icon: Icons.flight_land,
            label: 'Arrival',
            value: trip.arrivalPort != null
                ? '${trip.arrivalPort}'
                    '${trip.arrivalTime != null ? '\n${NavisDateUtils.formatDateTime(trip.arrivalTime!)}' : ''}'
                : 'Not recorded',
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
                label: 'Distance',
                value: DistanceUtils.formatDistance(
                  trip.distanceNm!,
                ),
                icon: Icons.straighten,
              ),
            ),
          if (trip.duration != null)
            Expanded(
              child: _StatBox(
                label: 'Duration',
                value: NavisDateUtils.formatDuration(
                  trip.duration!,
                ),
                icon: Icons.schedule,
              ),
            ),
          if (trip.avgSpeedKnots != null)
            Expanded(
              child: _StatBox(
                label: 'Avg Speed',
                value: DistanceUtils.formatSpeed(
                  trip.avgSpeedKnots!,
                ),
                icon: Icons.speed,
              ),
            ),
          if (trip.maxSpeedKnots != null)
            Expanded(
              child: _StatBox(
                label: 'Max Speed',
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
              label: 'Engine Hours',
              value: '${trip.engineHours!.toStringAsFixed(1)} h',
            ),
          if (trip.engineHours != null &&
              trip.fuelConsumedL != null) ...[
            const SizedBox(height: 12),
            Container(
              height: 0.5,
              color: AppColors.glassBorder,
            ),
            const SizedBox(height: 12),
          ],
          if (trip.fuelConsumedL != null)
            _DetailRow(
              icon: Icons.local_gas_station,
              label: 'Fuel Consumed',
              value:
                  '${trip.fuelConsumedL!.toStringAsFixed(1)} L',
            ),
        ],
      ),
    );
  }

  Widget _buildCrewCard(BuildContext context, Trip trip) {
    return NavisCard(
      child: _DetailRow(
        icon: Icons.group,
        label: 'Crew',
        value: trip.crewMembers!.join(', '),
      ),
    );
  }

  Widget _buildNotesCard(BuildContext context, Trip trip) {
    return NavisCard(
      child: _DetailRow(
        icon: Icons.notes,
        label: 'Notes',
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

  void _shareTrip(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.read(tripProvider(tripId));
    if (tripAsync case AsyncData(:final value)) {
      final trip = value;
      final distance = trip.distanceNm != null
          ? '${trip.distanceNm!.toStringAsFixed(1)} NM'
          : '';
      final duration = trip.duration != null
          ? '${trip.duration!.inHours}h ${trip.duration!.inMinutes % 60}m'
          : '';
      final text = StringBuffer()
        ..writeln(
          '${trip.departurePort} \u2192 ${trip.arrivalPort ?? '?'}',
        )
        ..writeln(
          trip.departureTime
              .toLocal()
              .toString()
              .substring(0, 16),
        )
        ..writeln(
          [distance, duration]
              .where((s) => s.isNotEmpty)
              .join(' \u2022 '),
        )
        ..writeln()
        ..write('Shared from Navis');
      Share.share(text.toString());
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.surfaceGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: AppColors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Delete Trip',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete this trip?',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: NavisButton(
                        label: 'Cancel',
                        variant: NavisButtonVariant.secondary,
                        compact: true,
                        onPressed: () =>
                            Navigator.of(ctx).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NavisButton(
                        label: 'Delete',
                        variant: NavisButtonVariant.danger,
                        icon: Icons.delete_outline,
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          try {
                            final repo = ref.read(
                              tripRepositoryProvider,
                            );
                            await repo.deleteTrip(tripId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Trip deleted'),
                                ),
                              );
                              context.pop();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to delete: $e',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedLegend extends StatelessWidget {
  const _SpeedLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: AppColors.cyan, label: '<3 kt'),
        const SizedBox(width: 12),
        _LegendDot(color: AppColors.green, label: '3-6 kt'),
        const SizedBox(width: 12),
        _LegendDot(color: AppColors.amber, label: '6-12 kt'),
        const SizedBox(width: 12),
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
                color: AppColors.textSecondary,
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
            color: AppColors.glassWhite,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.glassBorder,
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
                style:
                    Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
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
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}
