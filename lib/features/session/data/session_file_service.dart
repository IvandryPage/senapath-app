import 'dart:convert';

import 'package:xml/xml.dart';

import '../domain/ride_session.dart';

class SessionFileService {
  const SessionFileService();

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
    final document = XmlDocument.parse(content);
    final points = document.findAllElements('trkpt').toList(growable: false);
    if (points.isEmpty) {
      throw const FormatException('GPX tidak memiliki track point.');
    }

    return points
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
  }

  Map<String, Object?> _locationJson(TelemetryLocation location) => {
    'recordedAt': location.recordedAt.toUtc().toIso8601String(),
    ...location.toJson(),
  };
}
