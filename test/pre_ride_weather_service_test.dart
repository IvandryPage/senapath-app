import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senapath/features/routes/data/pre_ride_weather_service.dart';

void main() {
  test('requests current weather and parses the complete briefing payload', () async {
    Uri? requestedUri;
    final service = OpenMeteoPreRideWeatherService(
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          '{"current":{"temperature_2m":18.5,"weather_code":2,'
          '"wind_direction_10m":210,"wind_speed_10m":12.4,'
          '"time":"2026-09-30T08:00"}}',
          200,
        );
      }),
    );

    final weather = await service.fetchCurrentWeather(
      latitude: -6.2,
      longitude: 106.8,
    );

    expect(requestedUri?.queryParameters['current'], contains('weather_code'));
    expect(requestedUri?.queryParameters['wind_speed_unit'], 'kmh');
    expect(weather.temperatureCelsius, 18.5);
    expect(weather.condition, 'berawan sebagian');
    expect(weather.windDirectionFromDegrees, 210);
    expect(weather.toBriefingJson(windRelation: 'angin dari belakang'), {
      'condition': 'berawan sebagian',
      'temperatureCelsius': 18.5,
      'windDirectionFromDegrees': 210,
      'windSpeedKmh': 12.4,
      'windRelation': 'angin dari belakang',
      'observedAt': '2026-09-30T08:00:00.000',
    });
  });

  test('rejects invalid coordinates before making a request', () async {
    var requested = false;
    final service = OpenMeteoPreRideWeatherService(
      client: MockClient((_) async {
        requested = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      service.fetchCurrentWeather(latitude: 91, longitude: 0),
      throwsArgumentError,
    );
    expect(requested, isFalse);
  });
}
