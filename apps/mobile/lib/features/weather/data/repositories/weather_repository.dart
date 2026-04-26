import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/weather/data/models/weather_model.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather.dart';

class WeatherRepository {
  WeatherRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<Weather> getCurrentWeather(double lat, double lon) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/weather/current',
      queryParameters: {'lat': lat, 'lon': lon},
    );
    return WeatherModel.fromJson(response.data!).toEntity();
  }

  Future<List<Weather>> getForecast(double lat, double lon,
      {int days = 7}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/weather/forecast',
      queryParameters: {'lat': lat, 'lon': lon, 'days': days},
    );
    final items = (response.data!['forecast'] as List<dynamic>)
        .map((json) =>
            WeatherModel.fromJson(json as Map<String, dynamic>).toEntity())
        .toList();
    return items;
  }
}
