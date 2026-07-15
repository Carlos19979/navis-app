import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Scripted GPS so E2E runs never touch native location (the iOS permission
/// dialog would otherwise block the run) and trip recording gets a real,
/// moving track: start at Palma de Mallorca, head NE at ~6 kn, 1 Hz.
class FakeGeolocatorPlatform extends GeolocatorPlatform {
  double _lat = 39.5696;
  double _lon = 2.6347;

  Position _position() => Position(
        latitude: _lat,
        longitude: _lon,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 5,
        heading: 45,
        headingAccuracy: 5,
        speed: 3.1,
        speedAccuracy: 0.5,
        isMocked: true,
      );

  Position _advance() {
    _lat += 0.00002;
    _lon += 0.00003;
    return _position();
  }

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async =>
      _position();

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async =>
      _position();

  @override
  Stream<Position> getPositionStream({
    LocationSettings? locationSettings,
  }) {
    return Stream.periodic(const Duration(seconds: 1), (_) => _advance());
  }

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> openAppSettings() async => true;
}
