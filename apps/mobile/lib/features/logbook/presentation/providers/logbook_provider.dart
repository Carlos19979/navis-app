import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/session_provider.dart';

import 'package:navis_mobile/core/database/mutation_queue.dart';
import 'package:navis_mobile/core/database/offline_repository.dart';
import 'package:navis_mobile/features/logbook/data/repositories/trip_repository.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(
    offlineRepo: ref.watch(offlineRepositoryProvider),
    mutationQueue: ref.watch(mutationQueueProvider.notifier),
  );
});

final boatTripsProvider =
    FutureProvider.family<List<Trip>, String>((ref, boatId) async {
  ref.watch(sessionUserIdProvider);
  final repository = ref.watch(tripRepositoryProvider);
  final response = await repository.getTrips(boatId);
  return response.items.where((t) => t.status == TripStatus.completed).toList();
});

/// Every completed trip of the boat, following the cursor to the end.
///
/// The statistics screen used [boatTripsProvider], which is a single page of
/// 20 — so "all time" quietly meant "the last 20 trips" and the totals were
/// wrong for anyone with a real logbook. Aggregating needs the whole set.
///
/// Bounded by [_maxStatsPages] so a pathological logbook cannot page forever;
/// hitting the cap is logged rather than silently truncating.
final allBoatTripsProvider =
    FutureProvider.autoDispose.family<List<Trip>, String>((ref, boatId) async {
  ref.watch(sessionUserIdProvider);
  final repository = ref.watch(tripRepositoryProvider);

  final trips = <Trip>[];
  String? cursor;
  for (var page = 0; page < _maxStatsPages; page++) {
    final response = await repository.getTrips(
      boatId,
      cursor: cursor,
      limit: _statsPageSize,
    );
    trips.addAll(response.items);
    cursor = response.nextCursor;
    if (cursor == null) break;
    if (page == _maxStatsPages - 1) {
      debugPrint(
        'trip stats: stopped at $_maxStatsPages pages, totals are partial',
      );
    }
  }
  return trips
      .where((t) => t.status == TripStatus.completed)
      .toList(growable: false);
});

const _statsPageSize = 100;
const _maxStatsPages = 20;

final tripProvider = FutureProvider.family<Trip, String>((ref, id) async {
  ref.watch(sessionUserIdProvider);
  final repository = ref.watch(tripRepositoryProvider);
  return repository.getTrip(id);
});

final activeTripProvider = StateProvider<Trip?>((ref) => null);

class TripStats {
  const TripStats({
    required this.totalTrips,
    required this.totalDistanceNm,
    required this.totalHours,
  });

  final int totalTrips;
  final double totalDistanceNm;
  final double totalHours;
}

final tripStatsProvider = Provider.family<TripStats, List<Trip>>((ref, trips) {
  double totalDistance = 0;
  double totalHours = 0;

  for (final trip in trips) {
    totalDistance += trip.distanceNm ?? 0;
    if (trip.duration != null) {
      totalHours += trip.duration!.inMinutes / 60.0;
    }
  }

  return TripStats(
    totalTrips: trips.length,
    totalDistanceNm: totalDistance,
    totalHours: totalHours,
  );
});
