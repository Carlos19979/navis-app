import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:navis_mobile/features/weather/data/repositories/weather_repository.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather.dart';

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepository();
});

final currentWeatherProvider = FutureProvider<Weather?>((ref) async {
  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied ||
          requested == LocationPermission.deniedForever) {
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    ).timeout(const Duration(seconds: 5));

    final repository = ref.read(weatherRepositoryProvider);
    return repository.getCurrentWeather(position.latitude, position.longitude);
  } on Exception {
    return null;
  }
});

final forecastProvider = FutureProvider<List<Weather>>((ref) async {
  try {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    ).timeout(const Duration(seconds: 5));
    final repository = ref.read(weatherRepositoryProvider);
    return repository.getForecast(position.latitude, position.longitude);
  } on Exception {
    return [];
  }
});
