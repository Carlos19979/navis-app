import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Scripted geolocation for widget tests: deterministic permission answers,
/// a manually driven position stream ([emit]) and no real timers
/// (`Stream.periodic` would leak into the fake async zone and fail tests).
class FakeGeo extends GeolocatorPlatform {
  FakeGeo({
    this.checkResult = LocationPermission.whileInUse,
    LocationPermission? requestResult,
    this.serviceEnabled = true,
    Position? initialPosition,
  })  : requestResult = requestResult ?? checkResult,
        _position = initialPosition ?? makePosition();

  final LocationPermission checkResult;
  final LocationPermission requestResult;
  final bool serviceEnabled;

  /// Set to true when the screen under test opened location settings.
  bool openSettingsCalled = false;

  Position _position;
  final _controller = StreamController<Position>.broadcast();

  /// Pushes [position] to `getPositionStream` listeners and makes it the
  /// current/last-known position.
  void emit(Position position) {
    _position = position;
    _controller.add(position);
  }

  @override
  Future<LocationPermission> checkPermission() async => checkResult;

  @override
  Future<LocationPermission> requestPermission() async => requestResult;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async =>
      _position;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async =>
      _position;

  @override
  Stream<Position> getPositionStream({
    LocationSettings? locationSettings,
  }) =>
      _controller.stream;

  @override
  Future<bool> openLocationSettings() async {
    openSettingsCalled = true;
    return true;
  }

  @override
  Future<bool> openAppSettings() async => true;
}

/// Creates a [FakeGeo] and installs it as the [GeolocatorPlatform] instance.
FakeGeo installFakeGeo({
  LocationPermission checkResult = LocationPermission.whileInUse,
  LocationPermission? requestResult,
  bool serviceEnabled = true,
  Position? initialPosition,
}) {
  final fake = FakeGeo(
    checkResult: checkResult,
    requestResult: requestResult,
    serviceEnabled: serviceEnabled,
    initialPosition: initialPosition,
  );
  GeolocatorPlatform.instance = fake;
  return fake;
}

/// A plausible position (Palma de Mallorca, ~6 kn) for tests.
Position makePosition({
  double lat = 39.5696,
  double lon = 2.6347,
  double speedMs = 3.1,
}) {
  return Position(
    latitude: lat,
    longitude: lon,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 5,
    heading: 45,
    headingAccuracy: 5,
    speed: speedMs,
    speedAccuracy: 0.5,
    isMocked: true,
  );
}
