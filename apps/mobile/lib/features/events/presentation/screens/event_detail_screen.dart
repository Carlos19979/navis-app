import 'package:flutter/material.dart';
import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/shared/widgets/navis_list.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/charts/data/tile_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:navis_mobile/features/events/domain/entities/event.dart';
import 'package:navis_mobile/features/moderation/presentation/widgets/moderation_menu.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
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

  Future<void> _openLive(Event event) async {
    final url = (event.streamUrl != null && event.streamUrl!.isNotEmpty)
        ? event.streamUrl!
        : event.trackingUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      NavisSnackbar.error(
        context,
        AppLocalizations.of(context)!.couldNotOpenLive,
      );
    }
  }

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
      appBar: NavisAppBar(
        title: l.eventDetails,
        showBack: true,
        actions: [
          ModerationMenuButton(
            contentType: 'event',
            contentId: widget.eventId,
          ),
        ],
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
                Dimens.spaceLg,
                kToolbarHeight +
                    MediaQuery.of(context).padding.top +
                    Dimens.spaceLg,
                Dimens.spaceLg,
                Dimens.navClearance,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Map section
                  if (event.latitude != null && event.longitude != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Dimens.radiusSurface),
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
                              OpenSeaMapTileProvider.baseLayer(),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(
                                      event.latitude!,
                                      event.longitude!,
                                    ),
                                    width: 40,
                                    height: 40,
                                    child: Icon(
                                      Icons.location_on,
                                      color: context.accent,
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

                  // The event, as a heading and a list — not a card whose
                  // title competed with a star floating in a glowing disc.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (event.isFeatured) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Icon(
                            Icons.star_rounded,
                            color: context.caution,
                            size: Dimens.iconLg,
                            semanticLabel: l.featured,
                          ),
                        ),
                        const SizedBox(width: Dimens.spaceSm),
                      ],
                      Expanded(
                        child: Text(
                          event.name,
                          style: NavisType.display.copyWith(color: context.ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Dimens.spaceSm),
                  _EventTypeBadge(type: event.eventType),
                  const SizedBox(height: Dimens.spaceLg),
                  NavisList(
                    padding: EdgeInsets.zero,
                    children: [
                      NavisRow(
                        icon: Icons.calendar_today_outlined,
                        title: NavisDateUtils.formatDateTime(event.startDate),
                      ),
                      NavisRow(
                        icon: Icons.location_on_outlined,
                        title: event.locationName,
                      ),
                      NavisRow(
                        icon: Icons.person_outline_rounded,
                        title: event.organizer,
                      ),
                      if (event.boatClasses.isNotEmpty)
                        NavisRow(
                          icon: Icons.sailing_outlined,
                          title: event.boatClasses.join(', '),
                        ),
                    ],
                  ),
                  if (event.description != null) ...[
                    const SizedBox(height: Dimens.spaceLg),
                    Text(
                      event.description!,
                      style: NavisType.body.copyWith(color: context.inkMuted),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Action buttons
                  Column(
                    children: [
                      // Follow the regatta live (external YouTube / tracker).
                      if (event.hasLiveCoverage) ...[
                        // Supplementary → secondary, so "Join as group" reads
                        // as the single primary action for a regatta.
                        NavisButton(
                          label: l.followLive,
                          icon: Icons.live_tv,
                          variant: NavisButtonVariant.secondary,
                          onPressed: () => _openLive(event),
                        ),
                        const SizedBox(height: 10),
                      ],
                      // Join this event with one of the owner's groups, which
                      // creates a group regatta (visible in Groups → Regattas).
                      if (event.eventType == 'regatta') ...[
                        NavisButton(
                          label: l.joinAsGroup,
                          icon: Icons.groups,
                          onPressed: () => context.push(
                            Routes.eventStartRegatta(widget.eventId),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      NavisButton(
                        label:
                            event.isInterested ? l.notInterested : l.interested,
                        icon: event.isInterested
                            ? Icons.close
                            : Icons.favorite_outline,
                        variant:
                            event.eventType == 'regatta' || event.isInterested
                                ? NavisButtonVariant.secondary
                                : NavisButtonVariant.primary,
                        onPressed: _toggleRegistration,
                        isLoading: _isRegistering,
                      ),
                    ],
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
            context.accent.withValues(alpha: 0.2),
            context.accent.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.accent.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        type[0].toUpperCase() + type.substring(1),
        style: TextStyle(
          color: context.accent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
