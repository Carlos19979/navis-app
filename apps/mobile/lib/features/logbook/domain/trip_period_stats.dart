import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';

/// The slice of the logbook the statistics screen is showing: everything, a
/// single year, or a single month of a year.
///
/// One type for the three cases so the aggregation, the header and the chart
/// all agree on what "the period" is, instead of each recomputing its own
/// filter (the old screen hard-coded "all time" and "this year" and could show
/// nothing else).
class StatsPeriod {
  const StatsPeriod.allTime()
      : year = null,
        month = null;
  const StatsPeriod.year(int this.year) : month = null;
  const StatsPeriod.month(int this.year, int this.month);

  /// Null for all time.
  final int? year;

  /// 1-12, null when the whole year is selected.
  final int? month;

  bool get isAllTime => year == null;
  bool get isWholeYear => year != null && month == null;

  bool contains(DateTime when) {
    if (year == null) return true;
    if (when.year != year) return false;
    return month == null || when.month == month;
  }

  StatsPeriod withMonth(int? month) =>
      month == null ? StatsPeriod.year(year!) : StatsPeriod.month(year!, month);

  @override
  bool operator ==(Object other) =>
      other is StatsPeriod && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => 'StatsPeriod(year: $year, month: $month)';
}

/// A port and how many times it appears in the period, either as a departure
/// or an arrival.
class PortVisits {
  const PortVisits(this.port, this.visits);

  final String port;
  final int visits;
}

/// Every figure the statistics screen shows, for one period.
///
/// Deliberately free of anything with a currency in it: fuel *litres* and
/// engine hours belong to the logbook, while €/L, fuel spend and cost trends
/// are Cost intelligence's job and repeating them here would be two screens
/// disagreeing about the same number.
class TripPeriodStats {
  const TripPeriodStats({
    required this.trips,
    required this.distanceNm,
    required this.hours,
    required this.topSpeedKn,
    required this.fuelL,
    required this.engineHours,
    required this.ports,
    required this.tripsByMonth,
    required this.longestTripNm,
  });

  static const empty = TripPeriodStats(
    trips: 0,
    distanceNm: 0,
    hours: 0,
    topSpeedKn: 0,
    fuelL: 0,
    engineHours: 0,
    ports: [],
    tripsByMonth: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    longestTripNm: 0,
  );

  final int trips;
  final double distanceNm;
  final double hours;

  /// Best max-speed reading of the period; 0 when no trip recorded one.
  final double topSpeedKn;
  final double fuelL;
  final double engineHours;

  /// Ports by number of visits, most visited first.
  final List<PortVisits> ports;

  /// Trip count per calendar month, January first (12 entries).
  final List<int> tripsByMonth;
  final double longestTripNm;

  int get portCount => ports.length;

  /// Average speed over the period, from distance and time actually recorded.
  /// Null when either is missing, rather than a misleading 0 kn.
  double? get avgSpeedKn =>
      hours > 0 && distanceNm > 0 ? distanceNm / hours : null;

  /// Average trip length; null with no trips or no distance recorded.
  double? get avgTripNm =>
      trips > 0 && distanceNm > 0 ? distanceNm / trips : null;

  /// Litres per nautical mile — a consumption figure, not a cost one.
  double? get litresPerNm =>
      fuelL > 0 && distanceNm > 0 ? fuelL / distanceNm : null;
}

/// Aggregates [trips] (already filtered to the period) into its figures.
TripPeriodStats aggregateTrips(Iterable<Trip> trips) {
  var count = 0;
  var distance = 0.0;
  var hours = 0.0;
  var topSpeed = 0.0;
  var fuel = 0.0;
  var engine = 0.0;
  var longest = 0.0;
  final byMonth = List.filled(12, 0);
  // Insertion-ordered so equally-visited ports keep a stable order instead of
  // shuffling between rebuilds.
  final portVisits = <String, int>{};

  for (final trip in trips) {
    count++;
    distance += trip.distanceNm ?? 0;
    if ((trip.distanceNm ?? 0) > longest) longest = trip.distanceNm!;
    final duration = trip.duration;
    if (duration != null) hours += duration.inMinutes / 60.0;
    if ((trip.maxSpeedKnots ?? 0) > topSpeed) topSpeed = trip.maxSpeedKnots!;
    fuel += trip.fuelConsumedL ?? 0;
    engine += trip.engineHours ?? 0;
    byMonth[trip.departureTime.month - 1]++;

    for (final port in [trip.departurePort, trip.arrivalPort]) {
      final name = port?.trim();
      if (name == null || name.isEmpty) continue;
      portVisits[name] = (portVisits[name] ?? 0) + 1;
    }
  }

  final ports = portVisits.entries
      .map((e) => PortVisits(e.key, e.value))
      .toList(growable: false)
    ..sort((a, b) => b.visits.compareTo(a.visits));

  return TripPeriodStats(
    trips: count,
    distanceNm: distance,
    hours: hours,
    topSpeedKn: topSpeed,
    fuelL: fuel,
    engineHours: engine,
    ports: ports,
    tripsByMonth: byMonth,
    longestTripNm: longest,
  );
}

/// Years that have at least one trip, most recent first. What the year filter
/// offers — no empty years, and no guessing how far back the logbook goes.
List<int> yearsWithTrips(Iterable<Trip> trips) {
  final years = {for (final t in trips) t.departureTime.year}.toList()
    ..sort((a, b) => b.compareTo(a));
  return years;
}

/// Months (1-12) of [year] that have at least one trip.
Set<int> monthsWithTrips(Iterable<Trip> trips, int year) => {
      for (final t in trips)
        if (t.departureTime.year == year) t.departureTime.month,
    };
