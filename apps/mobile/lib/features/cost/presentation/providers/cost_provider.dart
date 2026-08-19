import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/features/cost/data/repositories/cost_repository.dart';
import 'package:navis_mobile/features/cost/domain/entities/cost_analytics.dart';
import 'package:navis_mobile/features/cost/domain/repositories/cost_repository.dart';
import 'package:navis_mobile/shared/models/analytics_period.dart';

final costRepositoryProvider =
    Provider<CostRepository>((ref) => CostRepositoryImpl());

/// Cost analytics for a boat. autoDispose so it refetches when revisited.
///
/// One request per visit: the response carries the whole month series, so
/// changing the period is arithmetic, not a round trip.
final boatCostAnalyticsProvider =
    FutureProvider.autoDispose.family<CostAnalytics, String>((ref, boatId) {
  return ref.watch(costRepositoryProvider).getForBoat(boatId);
});

/// Which slice of the history is on screen. Per visit, and reset when the screen
/// is left: coming back to "everything" is the useful default.
final costPeriodProvider = StateProvider.autoDispose<AnalyticsPeriod>(
  (ref) => const AnalyticsPeriod.allTime(),
);
