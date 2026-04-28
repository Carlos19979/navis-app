import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/stats_summary.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/trip_card.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

class LogbookScreen extends ConsumerWidget {
  const LogbookScreen({super.key, required this.boatId});

  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(boatTripsProvider(boatId));

    return Scaffold(
      appBar: const NavisAppBar(title: 'Logbook', showBack: true),
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
              message: 'No trips recorded yet. Start your first trip!',
              actionLabel: 'Record Trip',
              onAction: () => context.push('/boats/$boatId/record'),
            );
          }

          final stats = ref.watch(tripStatsProvider(trips));

          return RefreshIndicator(
            color: AppColors.cyan,
            onRefresh: () async {
              ref.invalidate(boatTripsProvider(boatId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: trips.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: StatsSummary(stats: stats),
                  );
                }
                return TripCard(trip: trips[index - 1]);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/boats/$boatId/record'),
        tooltip: 'Record trip',
        child: const Icon(Icons.play_arrow, semanticLabel: 'Record trip'),
      ),
    );
  }
}
