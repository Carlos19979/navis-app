import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/motion.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/boat/presentation/boat_actions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/stats_summary.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/trip_card.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_gradient_fab.dart';
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
        // Trip statistics live on the boat detail screen only; the logbook
        // used to duplicate that entry point in its app bar.
        appBar: NavisAppBar(title: l.logbook, showBack: true),
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
                onAction: () => context.push(Routes.boatPrecheck(boatId)),
              );
            }

            final stats = ref.watch(tripStatsProvider(trips));

            return RefreshIndicator(
              color: context.accent,
              backgroundColor: context.surfaceRaised,
              onRefresh: () async {
                ref.invalidate(boatTripsProvider(boatId));
              },
              child: ListView.builder(
                padding: Insets.gutterWithNav.add(
                  const EdgeInsets.only(top: Dimens.spaceLg),
                ),
                itemCount: trips.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: Dimens.spaceXl),
                      child: StatsSummary(stats: stats).entrance(),
                    );
                  }
                  // The shared entrance, which caps its stagger: this list was
                  // the reason the cap exists — at `100ms * index` the
                  // thirty-first trip waited three seconds and a scroll to
                  // item 60 met a blank list.
                  return TripCard(trip: trips[index - 1])
                      .entrance(index: index);
                },
              ),
            );
          },
        ),
        floatingActionButton: switch (ref.watch(boatProvider(boatId))) {
          // Through the shared action, so this button behaves like the other
          // three: it says «resume» and returns to the trip in progress
          // instead of walking the checklist again.
          AsyncData(:final value) when BoatActions.canSail(value) =>
            NavisGradientFab(
              icon: Icons.play_arrow_rounded,
              onPressed: () => BoatActions.sail(context, ref, value),
              tooltip: BoatActions.sailLabel(l, ref),
              heroTag: 'record_trip',
              label: BoatActions.sailLabel(l, ref),
            ),
          // Still loading: the permission is unknown, and a FAB that appears a
          // frame later is better than one that has to be taken away.
          AsyncLoading() => NavisGradientFab(
              icon: Icons.play_arrow_rounded,
              onPressed: () => context.push(Routes.boatPrecheck(boatId)),
              tooltip: l.startTrip,
              heroTag: 'record_trip',
              label: l.startTrip,
            ),
          _ => null,
        },
      ),
    );
  }
}
