import 'package:navis_mobile/features/weather/data/models/weather_model.dart';
import 'package:navis_mobile/features/weather/domain/entities/daily_weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/hourly_weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather_overview.dart';

final class HourlyWeatherModel {
  const HourlyWeatherModel({
    required this.time,
    required this.temperature,
    required this.windSpeed,
    required this.windDirection,
    required this.weatherCode,
    this.waveHeight,
    this.precipitationProbability,
  });

  factory HourlyWeatherModel.fromJson(Map<String, dynamic> json) {
    return HourlyWeatherModel(
      time: DateTime.parse(json['time'] as String),
      temperature: (json['temperature'] as num).toDouble(),
      windSpeed: (json['wind_speed'] as num).toDouble(),
      windDirection: (json['wind_direction'] as num).toDouble(),
      weatherCode: (json['weather_code'] as num?)?.toInt() ?? 0,
      waveHeight: (json['wave_height'] as num?)?.toDouble(),
      precipitationProbability:
          (json['precipitation_probability'] as num?)?.toInt(),
    );
  }

  final DateTime time;
  final double temperature;
  final double windSpeed;
  final double windDirection;
  final int weatherCode;
  final double? waveHeight;
  final int? precipitationProbability;

  HourlyWeather toEntity() => HourlyWeather(
        time: time,
        temperature: temperature,
        windSpeed: windSpeed,
        windDirection: windDirection,
        weatherCode: weatherCode,
        waveHeight: waveHeight,
        precipitationProbability: precipitationProbability,
      );
}

final class DailyWeatherModel {
  const DailyWeatherModel({
    required this.date,
    required this.temperatureMax,
    required this.temperatureMin,
    required this.windSpeed,
    required this.windDirection,
    required this.weatherCode,
    this.waveHeight,
  });

  factory DailyWeatherModel.fromJson(Map<String, dynamic> json) {
    return DailyWeatherModel(
      date: DateTime.parse(json['date'] as String),
      temperatureMax: (json['temperature_max'] as num).toDouble(),
      temperatureMin: (json['temperature_min'] as num).toDouble(),
      windSpeed: (json['wind_speed'] as num).toDouble(),
      windDirection: (json['wind_direction'] as num).toDouble(),
      weatherCode: (json['weather_code'] as num?)?.toInt() ?? 0,
      waveHeight: (json['wave_height'] as num?)?.toDouble(),
    );
  }

  final DateTime date;
  final double temperatureMax;
  final double temperatureMin;
  final double windSpeed;
  final double windDirection;
  final int weatherCode;
  final double? waveHeight;

  DailyWeather toEntity() => DailyWeather(
        date: date,
        temperatureMax: temperatureMax,
        temperatureMin: temperatureMin,
        windSpeed: windSpeed,
        windDirection: windDirection,
        weatherCode: weatherCode,
        waveHeight: waveHeight,
      );
}

final class WeatherOverviewModel {
  const WeatherOverviewModel({
    required this.current,
    required this.hourly,
    required this.daily,
    this.tideExtremes = const [],
  });

  factory WeatherOverviewModel.fromJson(Map<String, dynamic> json) {
    final hourlyJson = (json['hourly'] as List<dynamic>?) ?? const [];
    final dailyJson = (json['daily'] as List<dynamic>?) ?? const [];
    final tidesJson = (json['tide_extremes'] as List<dynamic>?) ?? const [];
    return WeatherOverviewModel(
      current: WeatherModel.fromJson(json['current'] as Map<String, dynamic>),
      hourly: hourlyJson
          .map((e) => HourlyWeatherModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      daily: dailyJson
          .map((e) => DailyWeatherModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      tideExtremes: tidesJson
          .map((e) => TideExtreme(
                time: DateTime.parse(e['time'] as String),
                height: (e['height'] as num).toDouble(),
                isHigh: e['kind'] == 'high',
              ))
          .toList(),
    );
  }

  final WeatherModel current;
  final List<HourlyWeatherModel> hourly;
  final List<DailyWeatherModel> daily;
  final List<TideExtreme> tideExtremes;

  WeatherOverview toEntity() => WeatherOverview(
        current: current.toEntity(),
        hourly: hourly.map((e) => e.toEntity()).toList(),
        daily: daily.map((e) => e.toEntity()).toList(),
        tideExtremes: tideExtremes,
      );
}
