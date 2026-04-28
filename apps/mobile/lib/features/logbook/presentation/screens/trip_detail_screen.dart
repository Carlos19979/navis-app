import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/distance_utils.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/charts/data/tile_provider.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripProvider(tripId));

    return Scaffold(
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
            icon: const Icon(Icons.delete_outlined, color: AppColors.red),
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
                if (hasTrack)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RepaintBoundary(
                      child: SizedBox(
                        height: 200,
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
                                  width: 12,
                                  height: 12,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: AppColors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Marker(
                                  point: LatLng(
                                    trackPoints.last.latitude,
                                    trackPoints.last.longitude,
                                  ),
                                  width: 12,
                                  height: 12,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: AppColors.red,
                                      shape: BoxShape.circle,
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
                if (hasTrack) ...[
                  const SizedBox(height: 8),
                  const _SpeedLegend(),
                ],
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(
                          icon: Icons.flight_takeoff,
                          label: 'Departure',
                          value:
                              '${trip.departurePort}\n${NavisDateUtils.formatDateTime(trip.departureTime)}',
                        ),
                        if (trip.arrivalPort != null) ...[
                          const Divider(height: 24),
                          _DetailRow(
                            icon: Icons.flight_land,
                            label: 'Arrival',
                            value:
                                '${trip.arrivalPort!}\n${trip.arrivalTime != null ? NavisDateUtils.formatDateTime(trip.arrivalTime!) : ''}',
                          ),
                        ],
                        if (trip.distanceNm != null) ...[
                          const Divider(height: 24),
                          _DetailRow(
                            icon: Icons.straighten,
                            label: 'Distance',
                            value: DistanceUtils.formatDistance(
                              trip.distanceNm!,
                            ),
                          ),
                        ],
                        if (trip.duration != null) ...[
                          const Divider(height: 24),
                          _DetailRow(
                            icon: Icons.timer_outlined,
                            label: 'Duration',
                            value: _formatDuration(trip.duration!),
                          ),
                        ],
                        if (trip.maxSpeedKnots != null ||
                            trip.avgSpeedKnots != null) ...[
                          const Divider(height: 24),
                          _DetailRow(
                            icon: Icons.speed,
                            label: 'Speed',
                            value: [
                              if (trip.maxSpeedKnots != null)
                                'Max: ${DistanceUtils.formatSpeed(trip.maxSpeedKnots!)}',
                              if (trip.avgSpeedKnots != null)
                                'Avg: ${DistanceUtils.formatSpeed(trip.avgSpeedKnots!)}',
                            ].join(' · '),
                          ),
                        ],
                        if (trip.engineHours != null) ...[
                          const Divider(height: 24),
                          _DetailRow(
                            icon: Icons.engineering,
                            label: 'Engine Hours',
                            value: '${trip.engineHours!.toStringAsFixed(1)} h',
                          ),
                        ],
                        if (trip.fuelConsumedL != null) ...[
                          const Divider(height: 24),
                          _DetailRow(
                            icon: Icons.local_gas_station,
                            label: 'Fuel Used',
                            value:
                                '${trip.fuelConsumedL!.toStringAsFixed(1)} L',
                          ),
                        ],
                        if (trip.crewMembers != null &&
                            trip.crewMembers!.isNotEmpty) ...[
                          const Divider(height: 24),
                          _DetailRow(
                            icon: Icons.group,
                            label: 'Crew',
                            value: trip.crewMembers!.join(', '),
                          ),
                        ],
                        if (trip.notes != null && trip.notes!.isNotEmpty) ...[
                          const Divider(height: 24),
                          _DetailRow(
                            icon: Icons.notes,
                            label: 'Notes',
                            value: trip.notes!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Polyline> _buildSpeedPolylines(List<TrackPoint> points) {
    if (points.length < 2) return [];

    final polylines = <Polyline>[];
    for (int i = 0; i < points.length - 1; i++) {
      final speed = points[i].speedKnots ?? 0;
      polylines.add(
        Polyline(
          points: [
            LatLng(points[i].latitude, points[i].longitude),
            LatLng(points[i + 1].latitude, points[i + 1].longitude),
          ],
          color: _speedColor(speed),
          strokeWidth: 3,
        ),
      );
    }
    return polylines;
  }

  static Color _speedColor(double knots) {
    if (knots < 3) return AppColors.cyan;
    if (knots < 6) return AppColors.green;
    if (knots < 12) return AppColors.amber;
    return AppColors.red;
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
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
            '${trip.departurePort} \u2192 ${trip.arrivalPort ?? '?'}')
        ..writeln(
            trip.departureTime.toLocal().toString().substring(0, 16))
        ..writeln([distance, duration].where((s) => s.isNotEmpty).join(' \u2022 '))
        ..writeln()
        ..write('Shared from Navis');
      Share.share(text.toString());
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Trip'),
        content: const Text(
          'Are you sure you want to delete this trip?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final repo = ref.read(tripRepositoryProvider);
                await repo.deleteTrip(tripId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Trip deleted')),
                  );
                  context.pop();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
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
        Icon(icon, size: 20, color: AppColors.cyan),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }
}
