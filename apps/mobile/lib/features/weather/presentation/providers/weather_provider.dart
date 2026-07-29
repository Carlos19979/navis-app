import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:navis_mobile/core/lifecycle/resume_refresh.dart';
import 'package:navis_mobile/features/weather/data/repositories/weather_repository.dart';
import 'package:navis_mobile/features/weather/domain/entities/hourly_weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather_overview.dart';

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepository();
});

/// Why there is no position, when there is none.
enum NoFixReason {
  /// Location services are off for the whole device.
  serviceDisabled,

  /// The app is not allowed to use location.
  permissionDenied,

  /// Allowed, but no fix came back (indoors, cold start, no last-known).
  unavailable,
}

/// A location fix, or the reason there isn't one.
///
/// The reason is the point. Everything on the weather screen hangs off the fix,
/// and when it is missing the user needs to know whether to turn location on,
/// grant the permission, or just step outside — a generic "we couldn't load the
/// forecast" (which is what a thrown geolocator call produced) is not something
/// anyone can act on.
class LocationFix {
  const LocationFix.found(Position this.position) : reason = null;
  const LocationFix.missing(NoFixReason this.reason) : position = null;

  final Position? position;
  final NoFixReason? reason;
}

Future<LocationFix> _getFix() async {
  // Every geolocator call is guarded, not just getCurrentPosition. They all
  // throw: services can be queried mid-toggle, `requestPermission` throws
  // `PermissionRequestInProgressException` when another screen is already
  // asking (the chart tab does), and `getLastKnownPosition` can throw too.
  // Any of those escaping turned the whole weather tab into an error screen.
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationFix.missing(NoFixReason.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const LocationFix.missing(NoFixReason.permissionDenied);
    }
  } on Exception catch (error) {
    debugPrint('location availability check failed: $error');
    return const LocationFix.missing(NoFixReason.unavailable);
  }

  try {
    return LocationFix.found(
      await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 12),
      ),
    );
  } on Exception catch (error) {
    debugPrint('current position unavailable, trying last known: $error');
  }

  try {
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return LocationFix.found(last);
  } on Exception catch (error) {
    debugPrint('last known position unavailable: $error');
  }
  return const LocationFix.missing(NoFixReason.unavailable);
}

/// The current fix with its failure reason. Re-acquired when the app comes back
/// to the foreground: the boat has usually moved while the phone was in a
/// pocket.
final locationFixProvider = FutureProvider<LocationFix>((ref) {
  ref.refreshOnAppResume(minInterval: ResumeRefresh.location);
  return _getFix();
});

/// The current position, or null when there is none.
///
/// Kept as the thing weather providers depend on — they only care whether there
/// is a position — while [locationFixProvider] carries the reason for the UI.
final positionProvider = FutureProvider<Position?>((ref) async {
  final fix = await ref.watch(locationFixProvider.future);
  return fix.position;
});

final currentWeatherProvider = FutureProvider<Weather?>((ref) async {
  final position = await ref.watch(positionProvider.future);
  if (position == null) return null;
  final repository = ref.read(weatherRepositoryProvider);
  return repository.getCurrentWeather(position.latitude, position.longitude);
});

final forecastProvider = FutureProvider<List<Weather>>((ref) async {
  final position = await ref.watch(positionProvider.future);
  if (position == null) return [];
  final repository = ref.read(weatherRepositoryProvider);
  return repository.getForecast(position.latitude, position.longitude);
});

/// What the weather screen renders. Refreshed on foreground return so the
/// forecast is not the one from whenever the tab was first opened; users were
/// having to pull-to-refresh every single time.
final weatherOverviewProvider = FutureProvider<WeatherOverview?>((ref) async {
  ref.refreshOnAppResume(minInterval: ResumeRefresh.forecast);
  final position = await ref.watch(positionProvider.future);
  if (position == null) return null;
  final repository = ref.read(weatherRepositoryProvider);
  return repository.getOverview(position.latitude, position.longitude);
});

/// Hourly forecast for a specific day, fetched on demand when the user taps a
/// day in the forecast list.
final hourlyForDayProvider =
    FutureProvider.family<List<HourlyWeather>, DateTime>((ref, day) async {
  final position = await ref.watch(positionProvider.future);
  if (position == null) return [];
  final repository = ref.read(weatherRepositoryProvider);
  return repository.getHourly(position.latitude, position.longitude, day);
});
