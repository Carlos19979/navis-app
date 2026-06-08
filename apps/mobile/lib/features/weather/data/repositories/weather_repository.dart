import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/weather/data/models/weather_model.dart';
import 'package:navis_mobile/features/weather/data/models/weather_overview_model.dart';
import 'package:navis_mobile/features/weather/domain/entities/hourly_weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather_overview.dart';

class WeatherRepository {
  WeatherRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<Weather> getCurrentWeather(double lat, double lon) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/weather/current',
      queryParameters: {'lat': lat, 'lon': lon},
    );
    final envelope = response.data!;
    return WeatherModel.fromJson(
      envelope['data'] as Map<String, dynamic>,
    ).toEntity();
  }

  Future<List<Weather>> getForecast(double lat, double lon,
      {int days = 7}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/weather/forecast',
      queryParameters: {'lat': lat, 'lon': lon, 'days': days},
    );
    final envelope = response.data!;
    final data = envelope['data'] as Map<String, dynamic>;
    final items = (data['forecast'] as List<dynamic>)
        .map((json) =>
            WeatherModel.fromJson(json as Map<String, dynamic>).toEntity())
        .toList();
    return items;
  }

  Future<WeatherOverview> getOverview(double lat, double lon) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/weather/overview',
      queryParameters: {'lat': lat, 'lon': lon},
    );
    final envelope = response.data!;
    return WeatherOverviewModel.fromJson(
      envelope['data'] as Map<String, dynamic>,
    ).toEntity();
  }

  /// Fetches the full hourly forecast for a single [day].
  Future<List<HourlyWeather>> getHourly(
    double lat,
    double lon,
    DateTime day,
  ) async {
    final date = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/weather/hourly',
      queryParameters: {'lat': lat, 'lon': lon, 'date': date},
    );
    final envelope = response.data!;
    final data = envelope['data'] as Map<String, dynamic>;
    return (data['hourly'] as List<dynamic>)
        .map((json) => HourlyWeatherModel.fromJson(json as Map<String, dynamic>)
            .toEntity())
        .toList();
  }
}
