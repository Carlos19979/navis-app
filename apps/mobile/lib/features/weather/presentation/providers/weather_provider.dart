import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:navis_mobile/features/weather/data/repositories/weather_repository.dart';
import 'package:navis_mobile/features/weather/domain/entities/hourly_weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather_overview.dart';

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepository();
});

Future<Position?> _getPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) return null;

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return null;
  }

  try {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 12),
    );
  } on Exception {
    return await Geolocator.getLastKnownPosition();
  }
}

final positionProvider = FutureProvider<Position?>((ref) => _getPosition());

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

final weatherOverviewProvider = FutureProvider<WeatherOverview?>((ref) async {
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
