import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/distance_utils.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/charts/data/tile_provider.dart';
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
                              polylines: [
                                Polyline(
                                  points: trackPoints
                                      .map((tp) =>
                                          LatLng(tp.latitude, tp.longitude))
                                      .toList(),
                                  color: AppColors.cyan,
                                  strokeWidth: 3,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
                        const Divider(height: 24),
                        if (trip.arrivalPort != null &&
                            trip.arrivalTime != null)
                          _DetailRow(
                            icon: Icons.flight_land,
                            label: 'Arrival',
                            value:
                                '${trip.arrivalPort}\n${NavisDateUtils.formatDateTime(trip.arrivalTime!)}',
                          ),
                        if (trip.distanceNm != null) ...[
                          const Divider(height: 24),
                          _DetailRow(
                            icon: Icons.straighten,
                            label: 'Distance',
                            value:
                                DistanceUtils.formatDistance(trip.distanceNm!),
                          ),
                        ],
                        if (trip.duration != null) ...[
                          const Divider(height: 24),
                          _DetailRow(
                            icon: Icons.schedule,
                            label: 'Duration',
                            value:
                                NavisDateUtils.formatDuration(trip.duration!),
                          ),
                        ],
                        if (trip.maxSpeedKnots != null) ...[
                          const Divider(height: 24),
                          _DetailRow(
                            icon: Icons.speed,
                            label: 'Max Speed',
                            value:
                                DistanceUtils.formatSpeed(trip.maxSpeedKnots!),
                          ),
                        ],
                        if (trip.avgSpeedKnots != null) ...[
                          const Divider(height: 24),
                          _DetailRow(
                            icon: Icons.trending_flat,
                            label: 'Avg Speed',
                            value:
                                DistanceUtils.formatSpeed(trip.avgSpeedKnots!),
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
