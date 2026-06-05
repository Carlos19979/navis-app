import 'package:flutter/material.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/charts/data/tile_provider.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
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
    final eventAsync = ref.watch(eventProvider(widget.eventId));
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NavisAppBar(
        title: l.eventDetails,
        showBack: true,
      ),
      body: GradientBackground(
        child: eventAsync.when(
          loading: () => const NavisLoading(),
          error: (error, stack) => NavisErrorWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(eventProvider(widget.eventId)),
          ),
          data: (event) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                kToolbarHeight + MediaQuery.of(context).padding.top + 16,
                16,
                100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Map section
                  if (event.latitude != null && event.longitude != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: RepaintBoundary(
                        child: SizedBox(
                          height: 200,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(
                                event.latitude!,
                                event.longitude!,
                              ),
                              interactionOptions: const InteractionOptions(
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
                    ).animate().fadeIn(duration: 500.ms),
                  const SizedBox(height: 16),

                  // Main info card
                  NavisCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                event.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: context.txtPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            if (event.isFeatured)
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.amber.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.amber
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.star,
                                  color: AppColors.amber,
                                  size: 20,
                                  semanticLabel: l.featured,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _EventTypeBadge(type: event.eventType),
                        const SizedBox(height: 16),
                        _InfoRow(
                          icon: Icons.calendar_today,
                          text: NavisDateUtils.formatDateTime(
                            event.startDate,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          text: event.locationName,
                        ),
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.person_outlined,
                          text: event.organizer,
                        ),
                        if (event.boatClasses.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _InfoRow(
                            icon: Icons.sailing_outlined,
                            text: event.boatClasses.join(', '),
                          ),
                        ],
                        if (event.description != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            height: 0.5,
                            color: context.glassBorderColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            event.description!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: context.txtSecondary,
                                  height: 1.5,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ).animate().fadeIn(
                        delay: 200.ms,
                        duration: 500.ms,
                      ),
                  const SizedBox(height: 16),

                  // Action button
                  NavisButton(
                    label: event.isInterested ? l.notInterested : l.interested,
                    icon: event.isInterested
                        ? Icons.close
                        : Icons.favorite_outline,
                    variant: event.isInterested
                        ? NavisButtonVariant.secondary
                        : NavisButtonVariant.primary,
                    onPressed: _toggleRegistration,
                    isLoading: _isRegistering,
                  ).animate().fadeIn(
                        delay: 400.ms,
                        duration: 500.ms,
                      ),
                ],
              ),
            );
          },
        ),
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
        horizontal: 12,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.cyan.withValues(alpha: 0.2),
            AppColors.cyan.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.cyan.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        type[0].toUpperCase() + type.substring(1),
        style: const TextStyle(
          color: AppColors.cyan,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
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
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: context.glassBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.cyan),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.txtPrimary,
                ),
          ),
        ),
      ],
    );
  }
}
