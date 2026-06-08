/// A single hour in an hourly forecast.
class HourlyWeather {
  const HourlyWeather({
    required this.time,
    required this.temperature,
    required this.windSpeed,
    required this.windDirection,
    required this.weatherCode,
    this.waveHeight,
    this.precipitationProbability,
  });

  final DateTime time;
  final double temperature;
  final double windSpeed;
  final double windDirection;
  final int weatherCode;
  final double? waveHeight;
  final int? precipitationProbability;
}
