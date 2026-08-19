import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/logbook/domain/trip_period_stats.dart';

import '../../helpers/helpers.dart';

void main() {
  group('aggregateTrips', () {
    test('sums the figures of the trips it is given', () {
      final stats = aggregateTrips([
        makeTrip(
          distanceNm: 20,
          maxSpeedKnots: 6,
          duration: const Duration(hours: 4),
          fuelConsumedL: 30,
          engineHours: 2,
        ),
        makeTrip(
          id: 'trip-2',
          distanceNm: 30,
          maxSpeedKnots: 9.5,
          duration: const Duration(hours: 6),
          fuelConsumedL: 45,
          engineHours: 3.5,
        ),
      ]);

      expect(stats.trips, 2);
      expect(stats.distanceNm, 50);
      expect(stats.hours, 10);
      expect(stats.topSpeedKn, 9.5);
      expect(stats.fuelL, 75);
      expect(stats.engineHours, 5.5);
      expect(stats.longestTripNm, 30);
      expect(stats.avgSpeedKn, 5);
      expect(stats.avgTripNm, 25);
      expect(stats.litresPerNm, 1.5);
    });

    test('counts visits per port, most visited first', () {
      final stats = aggregateTrips([
        makeTrip(departurePort: 'Palma', arrivalPort: 'Soller'),
        makeTrip(id: 't2', departurePort: 'Soller', arrivalPort: 'Palma'),
        makeTrip(id: 't3', departurePort: 'Palma', arrivalPort: 'Andratx'),
      ]);

      expect(stats.portCount, 3);
      expect(stats.ports.first.port, 'Palma');
      expect(stats.ports.first.visits, 3);
      expect(
        stats.ports.map((p) => p.port),
        containsAll(['Palma', 'Soller', 'Andratx']),
      );
    });

    test('ignores a missing or blank arrival port', () {
      final stats = aggregateTrips([
        makeTrip(departurePort: 'Palma', arrivalPort: null),
        makeTrip(id: 't2', departurePort: 'Palma', arrivalPort: '  '),
      ]);

      expect(stats.portCount, 1);
      expect(stats.ports.single.visits, 2);
    });

    test('counts trips per month of departure', () {
      final stats = aggregateTrips([
        makeTrip(departureTime: DateTime(2026, 1, 4)),
        makeTrip(id: 't2', departureTime: DateTime(2026, 7, 8)),
        makeTrip(id: 't3', departureTime: DateTime(2026, 7, 20)),
      ]);

      expect(stats.tripsByMonth[0], 1);
      expect(stats.tripsByMonth[6], 2);
      expect(stats.tripsByMonth[11], 0);
    });

    // A 0 kn average reads as a measurement, not as "we don't know".
    test('averages are null rather than zero without the data', () {
      final stats = aggregateTrips([
        makeTrip(distanceNm: null, maxSpeedKnots: null),
      ]);

      expect(stats.avgSpeedKn, isNull);
      expect(stats.avgTripNm, isNull);
      expect(stats.litresPerNm, isNull);
      expect(stats.topSpeedKn, 0);
    });

    test('an empty period aggregates to zeroes, not an error', () {
      final stats = aggregateTrips([]);

      expect(stats.trips, 0);
      expect(stats.distanceNm, 0);
      expect(stats.ports, isEmpty);
      expect(stats.tripsByMonth, hasLength(12));
    });
  });

  group('period options', () {
    test('years with trips are listed newest first, without gaps invented', () {
      final trips = [
        makeTrip(departureTime: DateTime(2024, 5, 3)),
        makeTrip(id: 't2', departureTime: DateTime(2026, 5, 3)),
        makeTrip(id: 't3', departureTime: DateTime(2026, 8, 3)),
      ];

      expect(yearsWithTrips(trips), [2026, 2024]);
    });

    test('months with trips are per year', () {
      final trips = [
        makeTrip(departureTime: DateTime(2026, 3, 3)),
        makeTrip(id: 't2', departureTime: DateTime(2026, 8, 3)),
        makeTrip(id: 't3', departureTime: DateTime(2025, 6, 3)),
      ];

      expect(monthsWithTrips(trips, 2026), {3, 8});
      expect(monthsWithTrips(trips, 2025), {6});
      expect(monthsWithTrips(trips, 2024), isEmpty);
    });
  });
}
