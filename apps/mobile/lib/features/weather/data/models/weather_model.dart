import 'package:navis_mobile/features/weather/domain/entities/weather.dart';

class WeatherModel {
  const WeatherModel({
    required this.temperature,
    required this.windSpeed,
    required this.windDirection,
    required this.waveHeight,
    required this.description,
    this.weatherCode = 0,
    this.humidity,
    this.pressure,
    this.icon,
    this.date,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    return WeatherModel(
      temperature: (json['temperature'] as num).toDouble(),
      windSpeed: (json['wind_speed'] as num).toDouble(),
      windDirection: (json['wind_direction'] as num).toDouble(),
      waveHeight: (json['wave_height'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      weatherCode: (json['weather_code'] as num?)?.toInt() ?? 0,
      humidity: (json['humidity'] as num?)?.toInt(),
      pressure: (json['pressure'] as num?)?.toDouble(),
      icon: json['icon'] as String?,
      date:
          json['date'] != null ? DateTime.parse(json['date'] as String) : null,
    );
  }

  final double temperature;
  final double windSpeed;
  final double windDirection;
  final double waveHeight;
  final String description;
  final int weatherCode;
  final int? humidity;
  final double? pressure;
  final String? icon;
  final DateTime? date;

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'wind_speed': windSpeed,
      'wind_direction': windDirection,
      'wave_height': waveHeight,
      'description': description,
      'weather_code': weatherCode,
      if (humidity != null) 'humidity': humidity,
      if (pressure != null) 'pressure': pressure,
      if (icon != null) 'icon': icon,
      if (date != null) 'date': date!.toIso8601String(),
    };
  }

  Weather toEntity() {
    return Weather(
      temperature: temperature,
      windSpeed: windSpeed,
      windDirection: windDirection,
      waveHeight: waveHeight,
      description: description,
      weatherCode: weatherCode,
      humidity: humidity,
      pressure: pressure,
      icon: icon,
      date: date,
    );
  }
}
