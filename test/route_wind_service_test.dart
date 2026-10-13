import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senapath/features/routes/data/route_wind_service.dart';
import 'package:senapath/features/routes/domain/route_wind.dart';

void main() {
  test('requests current wind direction for supplied GPS coordinates', () async {
    late http.Request request;
    final client = MockClient((incoming) async {
      request = incoming;
      return http.Response(
        jsonEncode({
          'current': {
            'time': '2026-10-13T06:00',
            'wind_direction_10m': 247,
          },
        }),
        200,
      );
    });
    final service = OpenMeteoRouteWindService(client: client);

    final observation = await service.fetchCurrentWind(
      latitude: -6.2,
      longitude: 106.8,
    );

    expect(request.method, 'GET');
    expect(request.url.host, 'api.open-meteo.com');
    expect(request.url.queryParameters['latitude'], '-6.20000');
    expect(request.url.queryParameters['longitude'], '106.80000');
    expect(request.url.queryParameters['current'], 'wind_direction_10m');
    expect(request.url.queryParameters.containsKey('wind_speed_10m'), isFalse);
    expect(observation.directionFromDegrees, 247);
    expect(observation.observedAt, DateTime.parse('2026-10-13T06:00'));
  });

  test('normalizes valid direction and rejects invalid weather payloads', () {
    expect(
      () => RouteWindObservation.fromJson({
        'current': {
          'time': '2026-10-13T06:00',
          'wind_direction_10m': 359.8,
        },
      }),
      returnsNormally,
    );
    expect(
      RouteWindObservation.fromJson({
        'current': {
          'time': '2026-10-13T06:00',
          'wind_direction_10m': 359.8,
        },
      }).directionFromDegrees,
      0,
    );
    expect(
      () => RouteWindObservation.fromJson({
        'current': {
          'time': '2026-10-13T06:00',
          'wind_direction_10m': 360,
        },
      }),
      throwsFormatException,
    );
    expect(
      () => RouteWindObservation.fromJson({'current': {}}),
      throwsFormatException,
    );
  });

  test('rejects invalid coordinates and HTTP errors', () async {
    final client = MockClient((_) async => http.Response('unavailable', 503));
    final service = OpenMeteoRouteWindService(client: client);
    await expectLater(
      service.fetchCurrentWind(latitude: 91, longitude: 0),
      throwsArgumentError,
    );
    await expectLater(
      service.fetchCurrentWind(latitude: 0, longitude: 0),
      throwsA(isA<StateError>()),
    );
  });
}
