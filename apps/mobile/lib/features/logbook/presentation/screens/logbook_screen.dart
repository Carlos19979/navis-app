import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/stats_summary.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/trip_card.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

class LogbookScreen extends ConsumerWidget {
  const LogbookScreen({super.key, required this.boatId});

  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final tripsAsync = ref.watch(boatTripsProvider(boatId));

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: NavisAppBar(
          title: l.logbook,
          showBack: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.bar_chart_outlined),
              tooltip: l.statistics,
              onPressed: () => context.push('/boats/$boatId/stats'),
            ),
          ],
        ),
        body: tripsAsync.when(
          loading: () => const NavisShimmer(itemCount: 4, itemHeight: 100),
          error: (error, stack) => NavisErrorWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(boatTripsProvider(boatId)),
          ),
          data: (trips) {
            if (trips.isEmpty) {
              return NavisEmptyState(
                icon: Icons.route_outlined,
                message: l.noTrips,
                actionLabel: l.recordTrip,
                onAction: () => context.push('/boats/$boatId/precheck'),
              );
            }

            final stats = ref.watch(tripStatsProvider(trips));

            return RefreshIndicator(
              color: AppColors.cyan,
              backgroundColor: AppColors.darkSurface,
              onRefresh: () async {
                ref.invalidate(boatTripsProvider(boatId));
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: trips.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: StatsSummary(stats: stats)
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(
                            begin: -0.1,
                            end: 0,
                            duration: 400.ms,
                          ),
                    );
                  }
                  return TripCard(trip: trips[index - 1])
                      .animate()
                      .fadeIn(
                        delay: (100 * index).ms,
                        duration: 400.ms,
                      )
                      .slideX(
                        begin: 0.05,
                        end: 0,
                        delay: (100 * index).ms,
                        duration: 400.ms,
                        curve: Curves.easeOut,
                      );
                },
              ),
            );
          },
        ),
        floatingActionButton: (ref
                    .watch(boatProvider(boatId))
                    .valueOrNull
                    ?.permissions
                    .canRecordTrips ??
                true)
            ? Container(
                decoration: BoxDecoration(
                  gradient: AppColors.cyanGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FloatingActionButton.extended(
                  heroTag: 'record_trip',
                  onPressed: () => context.push('/boats/$boatId/precheck'),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  icon: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                  ),
                  label: Text(
                    l.startTrip,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
