import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senapath/features/routes/data/overpass_route_places_service.dart';
import 'package:senapath/features/routes/domain/nearby_route_place.dart';
import 'package:senapath/features/routes/domain/saved_route.dart';

void main() {
  test('queries route vicinity and parses categorized OSM places', () async {
    late http.Request request;
    final client = MockClient((incoming) async {
      request = incoming;
      return http.Response(
        jsonEncode({
          'elements': [
            {
              'type': 'node',
              'id': 11,
              'lat': -6.2,
              'lon': 106.8,
              'tags': {'railway': 'station', 'name': 'Stasiun Utara'},
            },
            {
              'type': 'way',
              'id': 12,
              'center': {'lat': -6.201, 'lon': 106.801},
              'tags': {'amenity': 'bus_station'},
            },
            {
              'type': 'relation',
              'id': 13,
              'center': {'lat': -6.202, 'lon': 106.802},
              'tags': {'amenity': 'clinic', 'name': 'Klinik Sehat'},
            },
            {
              'type': 'node',
              'id': 14,
              'lat': -6.203,
              'lon': 106.803,
              'tags': {'shop': 'bicycle', 'name': 'Bengkel Pedal'},
            },
            {
              'type': 'node',
              'id': 15,
              'lat': -6.203,
              'lon': 106.803,
              'tags': {'amenity': 'cafe'},
            },
          ],
        }),
        200,
      );
    });
    final service = OverpassRoutePlacesService(
      client: client,
      endpoint: Uri.https('overpass.test', '/api/interpreter'),
    );

    final places = await service.findAlongRoute(_route());

    expect(request.method, 'POST');
    expect(request.url.host, 'overpass.test');
    expect(request.headers['user-agent'], contains('Senapath'));
    final query = request.bodyFields['data']!;
    expect(query, contains('around:700'));
    expect(query, contains('"railway"="station"'));
    expect(query, contains('"amenity"="bus_station"'));
    expect(query, contains('clinic|hospital|doctors'));
    expect(query, contains('"shop"="bicycle"'));
    expect(query, contains('"amenity"="bicycle_repair_station"'));
    expect(places, hasLength(4));
    expect(places[0].name, 'Stasiun Utara');
    expect(places[0].category, NearbyRoutePlaceCategory.trainStation);
    expect(places[1].name, 'Terminal');
    expect(places[1].category, NearbyRoutePlaceCategory.busTerminal);
    expect(places[2].latitude, -6.202);
    expect(places[2].category, NearbyRoutePlaceCategory.clinic);
    expect(places[3].osmUri.toString(), 'https://www.openstreetmap.org/node/14');
  });

  test('caps route sampling to keep long route requests bounded', () async {
    late http.Request request;
    final client = MockClient((incoming) async {
      request = incoming;
      return http.Response('{"elements":[]}', 200);
    });
    final route = _route(
      points: const [
        RoutePoint(
          latitude: 0,
          longitude: 0,
          elevationMeters: 0,
        ),
        RoutePoint(
          latitude: 0,
          longitude: 2,
          elevationMeters: 0,
        ),
      ],
    );
    final service = OverpassRoutePlacesService(client: client);

    await service.findAlongRoute(route);

    expect(
      RegExp(r'\["railway"="station"\]').allMatches(
        request.bodyFields['data']!,
      ),
      hasLength(30),
    );
  });

  test('rejects unsuccessful or malformed Overpass responses', () async {
    final service = OverpassRoutePlacesService(
      client: MockClient((_) async => http.Response('unavailable', 429)),
    );
    await expectLater(
      service.findAlongRoute(_route()),
      throwsA(isA<StateError>()),
    );

    final malformedService = OverpassRoutePlacesService(
      client: MockClient((_) async => http.Response('{"elements":{}}', 200)),
    );
    await expectLater(
      malformedService.findAlongRoute(_route()),
      throwsFormatException,
    );
  });

  test('rejects routes without enough points before making a request', () {
    final service = OverpassRoutePlacesService(
      client: MockClient((_) async => http.Response('{"elements":[]}', 200)),
    );
    expect(
      service.findAlongRoute(_route(points: const [])),
      throwsArgumentError,
    );
  });
}

RouteRecord _route({
  List<RoutePoint> points = const [
    RoutePoint(
      latitude: -6.2,
      longitude: 106.8,
      elevationMeters: 0,
    ),
    RoutePoint(
      latitude: -6.203,
      longitude: 106.803,
      elevationMeters: 0,
    ),
  ],
}) => RouteRecord(
  id: 'route-test',
  name: 'Loop Utara',
  source: 'GPX lokal',
  updatedAt: DateTime.utc(2026),
  availability: 'offline',
  points: points,
);
