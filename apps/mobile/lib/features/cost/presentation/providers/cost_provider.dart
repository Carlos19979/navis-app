import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/features/cost/data/cost_repository.dart';

/// Cost analytics for a boat. autoDispose so it refetches when revisited.
final boatCostAnalyticsProvider =
    FutureProvider.autoDispose.family<CostAnalytics, String>((ref, boatId) {
  return ref.watch(costRepositoryProvider).getForBoat(boatId);
});
