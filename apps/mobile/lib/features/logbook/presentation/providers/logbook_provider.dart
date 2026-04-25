import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/features/logbook/data/repositories/trip_repository.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository();
});

final boatTripsProvider =
    FutureProvider.family<List<Trip>, String>((ref, boatId) async {
  final repository = ref.watch(tripRepositoryProvider);
  final response = await repository.getTrips(boatId);
  return response.items;
});

final tripProvider =
    FutureProvider.family<Trip, String>((ref, id) async {
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

final tripStatsProvider =
    Provider.family<TripStats, List<Trip>>((ref, trips) {
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
