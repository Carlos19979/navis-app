class Weather {
  const Weather({
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

  Weather copyWith({
    double? temperature,
    double? windSpeed,
    double? windDirection,
    double? waveHeight,
    String? description,
    int? weatherCode,
    int? humidity,
    double? pressure,
    String? icon,
    DateTime? date,
  }) {
    return Weather(
      temperature: temperature ?? this.temperature,
      windSpeed: windSpeed ?? this.windSpeed,
      windDirection: windDirection ?? this.windDirection,
      waveHeight: waveHeight ?? this.waveHeight,
      description: description ?? this.description,
      weatherCode: weatherCode ?? this.weatherCode,
      humidity: humidity ?? this.humidity,
      pressure: pressure ?? this.pressure,
      icon: icon ?? this.icon,
      date: date ?? this.date,
    );
  }
}
