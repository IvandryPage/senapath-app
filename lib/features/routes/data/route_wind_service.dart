import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/route_wind.dart';

abstract interface class RouteWindService {
  Future<RouteWindObservation> fetchCurrentWind({
    required double latitude,
    required double longitude,
  });
}

class OpenMeteoRouteWindService implements RouteWindService {
  OpenMeteoRouteWindService({this.client});

  static final _endpoint = Uri.https('api.open-meteo.com', '/v1/forecast');

  final http.Client? client;

  @override
  Future<RouteWindObservation> fetchCurrentWind({
    required double latitude,
    required double longitude,
  }) async {
    if (!latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Invalid weather coordinates.');
    }
    final uri = _endpoint.replace(
      queryParameters: {
        'latitude': latitude.toStringAsFixed(5),
        'longitude': longitude.toStringAsFixed(5),
        'current': 'wind_direction_10m',
        'wind_speed_unit': 'ms',
        'timezone': 'auto',
      },
    );
    final requestClient = client ?? http.Client();
    try {
      final response = await requestClient
          .get(
            uri,
            headers: const {
              'User-Agent': 'Senapath/0.1 (route wind direction)',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw StateError('Open-Meteo returned ${response.statusCode}.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('Invalid Open-Meteo response.');
      }
      return RouteWindObservation.fromJson(Map<String, Object?>.from(decoded));
    } finally {
      if (client == null) requestClient.close();
    }
  }
}
