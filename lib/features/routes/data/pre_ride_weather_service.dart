import 'dart:convert';

import 'package:http/http.dart' as http;

class PreRideWeather {
  const PreRideWeather({
    required this.temperatureCelsius,
    required this.weatherCode,
    required this.windDirectionFromDegrees,
    required this.windSpeedKmh,
    required this.observedAt,
  });

  final double temperatureCelsius;
  final int weatherCode;
  final int windDirectionFromDegrees;
  final double windSpeedKmh;
  final DateTime observedAt;

  String get condition => switch (weatherCode) {
    0 => 'cerah',
    1 => 'sebagian besar cerah',
    2 => 'berawan sebagian',
    3 => 'berawan',
    45 || 48 => 'berkabut',
    51 || 53 || 55 => 'gerimis',
    56 || 57 => 'gerimis beku',
    61 || 63 || 65 => 'hujan',
    66 || 67 => 'hujan beku',
    71 || 73 || 75 || 77 => 'salju',
    80 || 81 || 82 => 'hujan deras berselang',
    85 || 86 => 'hujan salju berselang',
    95 || 96 || 99 => 'badai petir',
    _ => 'kondisi cuaca tidak diketahui',
  };

  Map<String, Object> toBriefingJson({required String windRelation}) => {
    'condition': condition,
    'temperatureCelsius': temperatureCelsius,
    'windDirectionFromDegrees': windDirectionFromDegrees,
    'windSpeedKmh': windSpeedKmh,
    'windRelation': windRelation,
    'observedAt': observedAt.toIso8601String(),
  };
}

abstract interface class PreRideWeatherService {
  Future<PreRideWeather> fetchCurrentWeather({
    required double latitude,
    required double longitude,
  });
}

class OpenMeteoPreRideWeatherService implements PreRideWeatherService {
  OpenMeteoPreRideWeatherService({this.client});

  static final _endpoint = Uri.https('api.open-meteo.com', '/v1/forecast');

  final http.Client? client;

  @override
  Future<PreRideWeather> fetchCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    if (!latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Invalid route-start weather coordinates.');
    }
    final uri = _endpoint.replace(
      queryParameters: {
        'latitude': latitude.toStringAsFixed(5),
        'longitude': longitude.toStringAsFixed(5),
        'current':
            'temperature_2m,weather_code,wind_direction_10m,wind_speed_10m',
        'wind_speed_unit': 'kmh',
        'timezone': 'auto',
      },
    );
    final requestClient = client ?? http.Client();
    try {
      final response = await requestClient
          .get(
            uri,
            headers: const {'User-Agent': 'Senapath/0.1 (pre-ride briefing)'},
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw StateError('Open-Meteo returned ${response.statusCode}.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['current'] is! Map) {
        throw const FormatException('Invalid current weather response.');
      }
      final current = Map<String, Object?>.from(decoded['current'] as Map);
      final temperature = (current['temperature_2m'] as num?)?.toDouble();
      final code = (current['weather_code'] as num?)?.toInt();
      final windDirection = (current['wind_direction_10m'] as num?)?.toDouble();
      final windSpeed = (current['wind_speed_10m'] as num?)?.toDouble();
      final observedAt = DateTime.tryParse(current['time'] as String? ?? '');
      if (temperature == null ||
          !temperature.isFinite ||
          code == null ||
          windDirection == null ||
          !windDirection.isFinite ||
          windDirection < 0 ||
          windDirection >= 360 ||
          windSpeed == null ||
          !windSpeed.isFinite ||
          windSpeed < 0 ||
          observedAt == null) {
        throw const FormatException('Invalid current weather values.');
      }
      return PreRideWeather(
        temperatureCelsius: temperature,
        weatherCode: code,
        windDirectionFromDegrees: windDirection.round() % 360,
        windSpeedKmh: windSpeed,
        observedAt: observedAt,
      );
    } finally {
      if (client == null) requestClient.close();
    }
  }
}
