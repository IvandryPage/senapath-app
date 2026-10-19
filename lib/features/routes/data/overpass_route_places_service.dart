import 'dart:convert';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../domain/nearby_route_place.dart';
import '../domain/saved_route.dart';

class OverpassRoutePlacesService {
  OverpassRoutePlacesService({this._client, Uri? endpoint})
    : _endpoint = endpoint ?? Uri.parse(defaultEndpoint);

  static const defaultEndpoint = 'https://overpass-api.de/api/interpreter';
  static const _searchRadiusMeters = 700;
  static const _maxSamplePoints = 30;

  final http.Client? _client;
  final Uri _endpoint;

  Future<List<NearbyRoutePlace>> findAlongRoute(RouteRecord route) async {
    if (route.points.length < 2) {
      throw ArgumentError.value(route.points.length, 'route.points');
    }
    final samples = _sampleRoute(route.points);
    final query = _buildQuery(samples);
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            _endpoint,
            headers: const {
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
              'User-Agent': 'Senapath/0.1 (OpenStreetMap route POI lookup)',
            },
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw StateError('Overpass returned ${response.statusCode}.');
      }
      return _parseResponse(response.body);
    } finally {
      if (_client == null) client.close();
    }
  }

  static List<({double latitude, double longitude})> _sampleRoute(
    List<RoutePoint> points,
  ) {
    final distances = <double>[0];
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      distances.add(
        distances.last +
            Geolocator.distanceBetween(
              previous.latitude,
              previous.longitude,
              current.latitude,
              current.longitude,
            ),
      );
    }

    final totalDistance = distances.last;
    final sampleCount = math.min(
      _maxSamplePoints,
      math.max(2, (totalDistance / _searchRadiusMeters).ceil() + 1),
    );
    final samples = <({double latitude, double longitude})>[];
    var segmentIndex = 1;
    for (var sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++) {
      final targetDistance = totalDistance * sampleIndex / (sampleCount - 1);
      while (segmentIndex < distances.length - 1 &&
          distances[segmentIndex] < targetDistance) {
        segmentIndex++;
      }
      final start = points[segmentIndex - 1];
      final end = points[segmentIndex];
      final segmentDistance =
          distances[segmentIndex] - distances[segmentIndex - 1];
      final fraction = segmentDistance == 0
          ? 0.0
          : ((targetDistance - distances[segmentIndex - 1]) / segmentDistance)
                .clamp(0.0, 1.0);
      final sample = (
        latitude: start.latitude + (end.latitude - start.latitude) * fraction,
        longitude:
            start.longitude + (end.longitude - start.longitude) * fraction,
      );
      if (samples.isEmpty ||
          _coordinateKey(samples.last) != _coordinateKey(sample)) {
        samples.add(sample);
      }
    }
    return samples;
  }

  static String _coordinateKey(({double latitude, double longitude}) point) =>
      '${point.latitude.toStringAsFixed(5)},'
      '${point.longitude.toStringAsFixed(5)}';

  static String _buildQuery(
    List<({double latitude, double longitude})> samples,
  ) {
    final clauses = <String>[];
    for (final point in samples) {
      final around =
          '(around:$_searchRadiusMeters,${point.latitude.toStringAsFixed(6)},'
          '${point.longitude.toStringAsFixed(6)})';
      clauses
        ..add('nwr$around["railway"="station"];')
        ..add('nwr$around["amenity"="bus_station"];')
        ..add('nwr$around["amenity"~"^(clinic|hospital|doctors)\$"];')
        ..add('nwr$around["shop"="bicycle"];')
        ..add('nwr$around["amenity"="bicycle_repair_station"];');
    }
    return '[out:json][timeout:25];(${clauses.join()});out center tags;';
  }

  static List<NearbyRoutePlace> _parseResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['elements'] is! List) {
      throw const FormatException('Invalid Overpass response.');
    }

    final places = <NearbyRoutePlace>[];
    final seen = <String>{};
    for (final element in decoded['elements'] as List) {
      if (element is! Map ||
          element['type'] is! String ||
          element['id'] is! int ||
          element['tags'] is! Map) {
        continue;
      }
      final tags = element['tags'] as Map;
      final category = _categoryFor(tags);
      if (category == null) continue;
      final center = element['center'];
      final latitude =
          (element['lat'] as num?)?.toDouble() ??
          (center is Map ? (center['lat'] as num?)?.toDouble() : null);
      final longitude =
          (element['lon'] as num?)?.toDouble() ??
          (center is Map ? (center['lon'] as num?)?.toDouble() : null);
      if (latitude == null ||
          longitude == null ||
          !latitude.isFinite ||
          !longitude.isFinite ||
          latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        continue;
      }

      final osmType = element['type'] as String;
      final osmId = element['id'] as int;
      if (!seen.add('$osmType/$osmId')) continue;
      final name = tags['name'];
      places.add(
        NearbyRoutePlace(
          osmType: osmType,
          osmId: osmId,
          name: name is String && name.trim().isNotEmpty
              ? name.trim()
              : category.label,
          category: category,
          latitude: latitude,
          longitude: longitude,
        ),
      );
    }
    return places;
  }

  static NearbyRoutePlaceCategory? _categoryFor(Map tags) {
    if (tags['railway'] == 'station') {
      return NearbyRoutePlaceCategory.trainStation;
    }
    if (tags['amenity'] == 'bus_station') {
      return NearbyRoutePlaceCategory.busTerminal;
    }
    if (const {'clinic', 'hospital', 'doctors'}.contains(tags['amenity'])) {
      return NearbyRoutePlaceCategory.clinic;
    }
    if (tags['shop'] == 'bicycle' ||
        tags['amenity'] == 'bicycle_repair_station') {
      return NearbyRoutePlaceCategory.bicycleRepair;
    }
    return null;
  }
}
