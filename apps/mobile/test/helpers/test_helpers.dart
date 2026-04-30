import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/events/domain/entities/event.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/profile/presentation/providers/profile_provider.dart';

Widget buildTestApp(
  Widget child, {
  List<Override> overrides = const [],
  NavigatorObserver? observer,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: child,
      navigatorObservers: observer != null ? [observer] : [],
    ),
  );
}

Widget buildTestAppWithScaffold(
  Widget child, {
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(body: child),
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
}) {
  return Boat(
    id: id,
    name: name,
    registration: registration,
    type: type,
    lengthMeters: lengthMeters,
    homePort: homePort,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

Document makeDocument({
  String id = 'doc-1',
  String boatId = 'boat-1',
  String type = 'Insurance',
  String? status = 'ok',
  int daysUntilExpiry = 180,
}) {
  return Document(
    id: id,
    boatId: boatId,
    type: type,
    expiryDate: DateTime.now().add(Duration(days: daysUntilExpiry)),
    status: status,
    notes: 'Test document',
    alertDaysBefore: 30,
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
