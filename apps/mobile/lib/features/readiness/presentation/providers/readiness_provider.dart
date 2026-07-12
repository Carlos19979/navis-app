import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/features/readiness/data/readiness_repository.dart';

/// Readiness summary for a boat. autoDispose so it refetches when revisited
/// (documents/maintenance may have changed).
final boatReadinessProvider =
    FutureProvider.autoDispose.family<Readiness, String>((ref, boatId) async {
  return ref.watch(readinessRepositoryProvider).getForBoat(boatId);
});
