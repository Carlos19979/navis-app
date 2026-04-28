import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/charts/data/tile_provider.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventDetailScreen> createState() =>
      _EventDetailScreenState();
}

class _EventDetailScreenState
    extends ConsumerState<EventDetailScreen> {
  bool _isRegistering = false;

  Future<void> _toggleRegistration() async {
    setState(() => _isRegistering = true);
    try {
      final repository = ref.read(eventRepositoryProvider);
      await repository.toggleInterest(widget.eventId);
      ref.invalidate(eventProvider(widget.eventId));
      ref.invalidate(eventsProvider);
    } finally {
      if (mounted) {
        setState(() => _isRegistering = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync =
        ref.watch(eventProvider(widget.eventId));

    return Scaffold(
      appBar: const NavisAppBar(
        title: 'Event Details',
        showBack: true,
      ),
      body: eventAsync.when(
        loading: () => const NavisLoading(),
        error: (error, stack) => NavisErrorWidget(
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(eventProvider(widget.eventId)),
        ),
        data: (event) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.latitude != null &&
                    event.longitude != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RepaintBoundary(
                      child: SizedBox(
                        height: 200,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              event.latitude!,
                              event.longitude!,
                            ),
                            interactionOptions:
                                const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            OpenSeaMapTileProvider.baseLayer,
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(
                                    event.latitude!,
                                    event.longitude!,
                                  ),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: AppColors.cyan,
                                    size: 40,
                                  ),
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
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                event.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                            ),
                            if (event.isFeatured)
                              const Icon(
                                Icons.star,
                                color: AppColors.amber,
                                semanticLabel: 'Featured',
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _EventTypeBadge(type: event.eventType),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.calendar_today,
                          text: NavisDateUtils.formatDateTime(
                            event.startDate,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          text: event.locationName,
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.person_outlined,
                          text: event.organizer,
                        ),
                        if (event.boatClasses.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.sailing_outlined,
                            text: event.boatClasses.join(', '),
                          ),
                        ],
                        if (event.description != null) ...[
                          const Divider(height: 24),
                          Text(
                            event.description!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                NavisButton(
                  label: event.isInterested
                      ? 'Not Interested'
                      : 'Interested',
                  onPressed: _toggleRegistration,
                  isLoading: _isRegistering,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EventTypeBadge extends StatelessWidget {
  const _EventTypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.cyan.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        type[0].toUpperCase() + type.substring(1),
        style: const TextStyle(
          color: AppColors.cyan,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
