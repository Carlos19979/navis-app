/// A single day in a multi-day forecast.
class DailyWeather {
  const DailyWeather({
    required this.date,
    required this.temperatureMax,
    required this.temperatureMin,
    required this.windSpeed,
    required this.windDirection,
    required this.weatherCode,
    this.waveHeight,
  });

  final DateTime date;
  final double temperatureMax;
  final double temperatureMin;
  final double windSpeed;
  final double windDirection;
  final int weatherCode;
  final double? waveHeight;
}
