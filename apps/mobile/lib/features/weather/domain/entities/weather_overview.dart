import 'package:navis_mobile/features/weather/domain/entities/daily_weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/hourly_weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather.dart';

/// Current conditions bundled with hourly (next 24h) and daily forecasts,
/// mirroring the layout of a typical weather app.
class WeatherOverview {
  const WeatherOverview({
    required this.current,
    required this.hourly,
    required this.daily,
    this.tideExtremes = const [],
  });

  final Weather current;
  final List<HourlyWeather> hourly;
  final List<DailyWeather> daily;
  final List<TideExtreme> tideExtremes;
}

/// A high or low tide turning point.
class TideExtreme {
  const TideExtreme({
    required this.time,
    required this.height,
    required this.isHigh,
  });

  final DateTime time;
  final double height;
  final bool isHigh;
}
