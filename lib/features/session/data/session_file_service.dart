import 'dart:convert';

import 'package:xml/xml.dart';

import '../domain/ride_session.dart';

class GpxImport {
  const GpxImport({
    required this.name,
    required this.description,
    required this.locations,
  });

  final String? name;
  final String? description;
  final List<TelemetryLocation> locations;
}

class SessionFileService {
  const SessionFileService();

  static const maximumGpxBytes = 10 * 1024 * 1024;

  String toJson({
    required RideSessionSnapshot session,
    required List<TelemetryLocation> locations,
  }) {
    final payload = {
      'schemaVersion': 1,
      'type': 'senapath.session',
      'session': {
        'id': session.id,
        'startedAt': session.startedAt.toUtc().toIso8601String(),
        'endedAt': session.endedAt?.toUtc().toIso8601String(),
        'distanceMeters': session.distanceMeters,
        'currentSpeedMetersPerSecond': session.currentSpeedMetersPerSecond,
        'syncStatus': session.syncStatus,
      },
      'track': locations.map(_locationJson).toList(growable: false),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String toGpx(List<TelemetryLocation> locations) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'gpx',
      attributes: {
        'version': '1.1',
        'creator': 'Senapath',
        'xmlns': 'http://www.topografix.com/GPX/1/1',
      },
      nest: () {
        builder.element(
          'trk',
          nest: () {
            builder.element('name', nest: 'Senapath session');
            builder.element(
              'trkseg',
              nest: () {
                for (final location in locations) {
                  builder.element(
                    'trkpt',
                    attributes: {
                      'lat': location.latitude.toString(),
                      'lon': location.longitude.toString(),
                    },
                    nest: () {
                      builder.element(
                        'ele',
                        nest: location.altitudeMeters.toString(),
                      );
                      builder.element(
                        'time',
                        nest: location.recordedAt.toUtc().toIso8601String(),
                      );
                    },
                  );
                }
              },
            );
          },
        );
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }

  List<TelemetryLocation> parseGpx(String content) {
    return parseGpxDocument(content).locations;
  }

  GpxImport parseGpxDocument(String content) {
    if (utf8.encode(content).length > maximumGpxBytes) {
      throw const FormatException(
        'Ukuran GPX melebihi batas 10 MB.',
      );
    }
    final document = XmlDocument.parse(content);
    final points = document.findAllElements('trkpt').toList(growable: false);
    if (points.isEmpty) {
      throw const FormatException('GPX tidak memiliki track point.');
    }

    final locations = points
        .map((point) {
          final latitude = double.tryParse(point.getAttribute('lat') ?? '');
          final longitude = double.tryParse(point.getAttribute('lon') ?? '');
          final elevation = double.tryParse(
            point.getElement('ele')?.innerText ?? '0',
          );
          final time = DateTime.tryParse(
            point.getElement('time')?.innerText ?? '',
          );
          if (latitude == null ||
              longitude == null ||
              !latitude.isFinite ||
              !longitude.isFinite ||
              latitude < -90 ||
              latitude > 90 ||
              longitude < -180 ||
              longitude > 180 ||
              time == null) {
            throw const FormatException(
              'GPX memiliki track point tidak valid.',
            );
          }
          return TelemetryLocation(
            recordedAt: time.toUtc(),
            latitude: latitude,
            longitude: longitude,
            accuracyMeters: double.nan,
            altitudeMeters: elevation ?? 0,
            speedMetersPerSecond: 0,
          );
        })
        .toList(growable: false);
    final track = document.findAllElements('trk').firstOrNull;
    final name = _firstText([
      track?.getElement('name'),
      document.findAllElements('metadata').firstOrNull?.getElement('name'),
      document.findAllElements('name').firstOrNull,
    ]);
    final description = _firstText([
      track?.getElement('desc'),
      document.findAllElements('metadata').firstOrNull?.getElement('desc'),
      document.findAllElements('desc').firstOrNull,
    ]);

    return GpxImport(
      name: name,
      description: description,
      locations: locations,
    );
  }

  String? _firstText(Iterable<XmlElement?> elements) {
    for (final element in elements) {
      final text = element?.innerText.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  Map<String, Object?> _locationJson(TelemetryLocation location) => {
    'recordedAt': location.recordedAt.toUtc().toIso8601String(),
    ...location.toJson(),
  };
}
