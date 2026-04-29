import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:navis_mobile/features/weather/data/repositories/weather_repository.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather.dart';

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
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 10),
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
