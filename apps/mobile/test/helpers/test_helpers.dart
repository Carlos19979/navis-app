import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/anomaly/data/anomaly_repository.dart';
import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/cost/data/cost_repository.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_models.dart';
import 'package:navis_mobile/features/readiness/data/readiness_repository.dart';
import 'package:navis_mobile/features/regattas/domain/entities/regatta.dart';
import 'package:navis_mobile/features/shared/data/shared_repository.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/events/domain/entities/event.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/weather/domain/entities/daily_weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/hourly_weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather_overview.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/profile/presentation/providers/profile_provider.dart';

/// Default boatProvider override so screens that gate write-actions on
/// boat ownership get an owned boat unless a test overrides it.
final _defaultBoatOverride = boatProvider.overrideWith(
  (ref, id) async => Boat(
    id: id,
    name: 'Test Boat',
    registration: 'TEST-1',
    type: 'sailboat',
    lengthMeters: 10,
  ),
);

/// Overrides applied by every test app builder ([buildTestApp],
/// [buildTestAppWithScaffold] and `buildRoutedTestApp` in router.dart).
final defaultTestOverrides = <Override>[_defaultBoatOverride];

Widget buildTestApp(
  Widget child, {
  List<Override> overrides = const [],
  NavigatorObserver? observer,
}) {
  return ProviderScope(
    overrides: [...defaultTestOverrides, ...overrides],
    child: MaterialApp(
      home: child,
      navigatorObservers: observer != null ? [observer] : [],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
      ],
    ),
  );
}

Widget buildTestAppWithScaffold(
  Widget child, {
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [...defaultTestOverrides, ...overrides],
    child: MaterialApp(
      home: Scaffold(body: child),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
      ],
    ),
  );
}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

class FakeRoute extends Fake implements Route<dynamic> {}

// --- Test Data Factories ---

Boat makeBoat({
  String id = 'boat-1',
  String name = 'Luna Azul',
  String registration = 'ES-MAL-3-1234',
  String type = 'sailboat',
  double lengthMeters = 12.5,
  String? homePort = 'Palma de Mallorca',
  String? photoUrl,
  List<String> photoUrls = const [],
}) {
  return Boat(
    id: id,
    name: name,
    registration: registration,
    type: type,
    lengthMeters: lengthMeters,
    homePort: homePort,
    photoUrl: photoUrl,
    photoUrls: photoUrls,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

Document makeDocument({
  String id = 'doc-1',
  String boatId = 'boat-1',
  String type = 'Insurance',
  String? customName,
  String? status = 'ok',
  int daysUntilExpiry = 180,
  List<int>? alertDays,
}) {
  return Document(
    id: id,
    boatId: boatId,
    type: type,
    customName: customName,
    expiryDate: DateTime.now().add(Duration(days: daysUntilExpiry)),
    status: status,
    notes: 'Test document',
    alertDaysBefore:
        alertDays != null && alertDays.isNotEmpty ? alertDays.first : 30,
    alertDays: alertDays,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

Trip makeTrip({
  String id = 'trip-1',
  String boatId = 'boat-1',
  String departurePort = 'Palma de Mallorca',
  String? arrivalPort = 'Port de Soller',
  TripStatus status = TripStatus.completed,
  double? distanceNm = 28.5,
  double? maxSpeedKnots = 7.1,
}) {
  return Trip(
    id: id,
    boatId: boatId,
    departurePort: departurePort,
    departureTime: DateTime(2026, 4, 26, 10),
    arrivalPort: arrivalPort,
    arrivalTime:
        status == TripStatus.completed ? DateTime(2026, 4, 26, 14, 30) : null,
    distanceNm: distanceNm,
    maxSpeedKnots: maxSpeedKnots,
    status: status,
    crewMembers: const ['Carlos', 'Maria'],
    notes: 'Great trip',
    createdAt: DateTime(2026, 4, 26),
    updatedAt: DateTime(2026, 4, 26),
  );
}

Event makeEvent({
  String id = 'event-1',
  String name = 'Copa del Rey',
  String organizer = 'RCNP',
  String eventType = 'regatta',
  bool isFeatured = true,
}) {
  return Event(
    id: id,
    name: name,
    organizer: organizer,
    eventType: eventType,
    locationName: 'Palma de Mallorca',
    startDate: DateTime(2026, 7, 31),
    endDate: DateTime(2026, 8, 6),
    description: 'Major regatta event',
    isFeatured: isFeatured,
    boatClasses: const ['TP52', 'J80'],
    latitude: 39.5696,
    longitude: 2.6347,
  );
}

Weather makeWeather({
  double temperature = 24.0,
  double windSpeed = 12.0,
  double windDirection = 225.0,
  double waveHeight = 0.8,
}) {
  return Weather(
    temperature: temperature,
    windSpeed: windSpeed,
    windDirection: windDirection,
    waveHeight: waveHeight,
    description: 'Partly cloudy',
    humidity: 65,
    pressure: 1013.0,
    icon: '02d',
  );
}

Weather makeForecast(DateTime date) {
  return Weather(
    temperature: 22.0,
    windSpeed: 10.0,
    windDirection: 180.0,
    waveHeight: 0.5,
    description: 'Sunny',
    date: date,
  );
}

HourlyWeather makeHourly(
  DateTime time, {
  double temperature = 20.0,
  double windSpeed = 12.0,
  int weatherCode = 0,
  double? waveHeight = 0.5,
  int? precipitationProbability = 0,
}) {
  return HourlyWeather(
    time: time,
    temperature: temperature,
    windSpeed: windSpeed,
    windDirection: 225.0,
    weatherCode: weatherCode,
    waveHeight: waveHeight,
    precipitationProbability: precipitationProbability,
  );
}

DailyWeather makeDaily(
  DateTime date, {
  double temperatureMax = 26.0,
  double temperatureMin = 18.0,
  double windSpeed = 10.0,
  int weatherCode = 0,
  double? waveHeight = 0.5,
}) {
  return DailyWeather(
    date: date,
    temperatureMax: temperatureMax,
    temperatureMin: temperatureMin,
    windSpeed: windSpeed,
    windDirection: 180.0,
    weatherCode: weatherCode,
    waveHeight: waveHeight,
  );
}

WeatherOverview makeOverview({
  Weather? current,
  List<HourlyWeather>? hourly,
  List<DailyWeather>? daily,
  List<TideExtreme> tideExtremes = const [],
}) {
  return WeatherOverview(
    current: current ?? makeWeather(),
    hourly: hourly ?? [makeHourly(DateTime(2026, 5, 1, 12))],
    daily: daily ?? [makeDaily(DateTime(2026, 5))],
    tideExtremes: tideExtremes,
  );
}

UserProfile makeProfile() {
  return const UserProfile(
    id: 'user-1',
    email: 'test@navis.app',
    displayName: 'Test User',
  );
}

TripStats makeTripStats() {
  return const TripStats(
    totalTrips: 5,
    totalDistanceNm: 142.3,
    totalHours: 24.5,
  );
}

Booking makeBooking({
  String id = 'booking-1',
  String boatId = 'boat-1',
  String userId = 'user-1',
  DateTime? startsAt,
  DateTime? endsAt,
  String status = 'confirmed',
  String? purpose = 'Weekend sail',
}) {
  return Booking(
    id: id,
    boatId: boatId,
    userId: userId,
    startsAt: startsAt ?? DateTime(2026, 5, 1, 10),
    endsAt: endsAt ?? DateTime(2026, 5, 1, 18),
    status: status,
    purpose: purpose,
  );
}

BoatMember makeBoatMember({
  String userId = 'user-2',
  String name = 'Maria',
  BoatPermissions permissions = const BoatPermissions(),
}) {
  return BoatMember(userId: userId, name: name, permissions: permissions);
}

MaintenanceTask makeMaintenanceTask({
  String id = 'task-1',
  String boatId = 'boat-1',
  String name = 'Engine oil change',
  MaintenanceStatus status = MaintenanceStatus.ok,
  int? intervalMonths = 12,
  double? intervalHours,
  DateTime? lastPerformedAt,
  double? lastEngineHours,
  DateTime? nextDueDate,
  int? nextDueDays = 90,
  double? hoursUntilDue,
}) {
  return MaintenanceTask(
    id: id,
    boatId: boatId,
    name: name,
    status: status,
    intervalMonths: intervalMonths,
    intervalHours: intervalHours,
    lastPerformedAt: lastPerformedAt ?? DateTime(2026, 3, 15),
    lastEngineHours: lastEngineHours,
    nextDueDate: nextDueDate ?? DateTime(2027, 3, 15),
    nextDueDays: nextDueDays,
    hoursUntilDue: hoursUntilDue,
  );
}

MaintenanceLog makeMaintenanceLog({
  String id = 'log-1',
  String boatId = 'boat-1',
  String type = 'engine_service',
  DateTime? performedAt,
  String? taskId,
  double? engineHours = 120,
  double? cost = 250,
  String? provider = 'Marina Service',
  String? notes,
  String? invoiceUrl,
  List<String> photoUrls = const [],
}) {
  return MaintenanceLog(
    id: id,
    boatId: boatId,
    type: type,
    performedAt: performedAt ?? DateTime(2026, 3, 15),
    taskId: taskId,
    engineHours: engineHours,
    cost: cost,
    provider: provider,
    notes: notes,
    invoiceUrl: invoiceUrl,
    photoUrls: photoUrls,
  );
}

Expense makeExpense({
  String id = 'expense-1',
  String boatId = 'boat-1',
  String category = 'fuel',
  double amount = 85.5,
  DateTime? incurredOn,
  String? notes,
  String? invoiceUrl,
}) {
  return Expense(
    id: id,
    boatId: boatId,
    category: category,
    amount: amount,
    incurredOn: incurredOn ?? DateTime(2026, 4, 20),
    notes: notes,
    invoiceUrl: invoiceUrl,
  );
}

Group makeGroup({
  String id = 'group-1',
  String ownerId = 'user-1',
  String name = 'Palma Sailing Club',
  String visibility = 'public',
  String? description = 'Weekend sailors',
  String? inviteCode,
  int memberCount = 5,
  int pendingCount = 0,
  String myMembershipStatus = 'active',
  String myRole = 'owner',
}) {
  return Group(
    id: id,
    ownerId: ownerId,
    name: name,
    visibility: visibility,
    description: description,
    inviteCode: inviteCode,
    memberCount: memberCount,
    pendingCount: pendingCount,
    myMembershipStatus: myMembershipStatus,
    myRole: myRole,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

Regatta makeRegatta({
  String id = 'regatta-1',
  String boatId = 'boat-1',
  String ownerId = 'user-1',
  String kind = 'regatta',
  String status = 'planned',
  String departurePort = 'Palma de Mallorca',
  String? groupId = 'group-1',
  String? title = 'Spring Cup',
  DateTime? scheduledAt,
  bool checklistCompleted = false,
}) {
  return Regatta(
    id: id,
    boatId: boatId,
    ownerId: ownerId,
    kind: kind,
    status: status,
    departurePort: departurePort,
    groupId: groupId,
    title: title,
    scheduledAt: scheduledAt ?? DateTime(2026, 6, 15, 10),
    checklistCompleted: checklistCompleted,
  );
}

Readiness makeReadiness({
  int score = 92,
  ReadinessStatus status = ReadinessStatus.ready,
  bool full = true,
  List<ReadinessCategory>? categories,
  List<ReadinessItem>? attention,
}) {
  return Readiness(
    score: score,
    status: status,
    full: full,
    categories: categories ??
        const [
          ReadinessCategory(
            key: 'documents',
            status: ReadinessStatus.ready,
            total: 3,
            expired: 0,
            critical: 0,
            warning: 1,
            ok: 2,
          ),
        ],
    attention: attention ?? const [],
  );
}

CostAnalytics makeCostAnalytics({
  double totalSpend = 1250,
  double expenseSpend = 950,
  double maintenanceSpend = 300,
  List<CostBreakdownItem>? byCategory,
  List<CostMonthly>? monthly,
  double totalDistanceNm = 142.3,
  int completedTrips = 5,
  double totalFuelL = 180,
  double? costPerNm = 8.8,
  double? costPerTrip = 250,
  double? fuelPerNm = 1.3,
}) {
  return CostAnalytics(
    totalSpend: totalSpend,
    expenseSpend: expenseSpend,
    maintenanceSpend: maintenanceSpend,
    byCategory: byCategory ??
        const [
          CostBreakdownItem(key: 'fuel', amount: 500),
          CostBreakdownItem(key: 'mooring', amount: 450),
          CostBreakdownItem(key: 'maintenance', amount: 300),
        ],
    monthly: monthly ??
        const [
          CostMonthly(month: '2026-03', amount: 400),
          CostMonthly(month: '2026-04', amount: 850),
        ],
    totalDistanceNm: totalDistanceNm,
    completedTrips: completedTrips,
    totalFuelL: totalFuelL,
    costPerNm: costPerNm,
    costPerTrip: costPerTrip,
    fuelPerNm: fuelPerNm,
  );
}

Anomaly makeAnomaly({
  String tripId = 'trip-1',
  DateTime? date,
  String metric = 'fuel_per_nm',
  double value = 2.4,
  double baseline = 1.3,
  double deviationPct = 84.6,
}) {
  return Anomaly(
    tripId: tripId,
    date: date ?? DateTime(2026, 4, 26),
    metric: metric,
    value: value,
    baseline: baseline,
    deviationPct: deviationPct,
  );
}
