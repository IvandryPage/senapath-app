import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/data/custom_auth_session_manager.dart';
import '../domain/saved_route.dart';

abstract interface class RoutePlannerGateway {
  bool get isConfigured;

  Future<RouteRecord> planCyclingRoute({
    required double originLatitude,
    required double originLongitude,
    required String destination,
  });
}

class GoogleMapsRoutePlannerGateway implements RoutePlannerGateway {
  const GoogleMapsRoutePlannerGateway({
    required this.client,
    required this.sessionManager,
  });

  final SupabaseClient? client;
  final CustomAuthSessionManager sessionManager;

  @override
  bool get isConfigured => client != null;

  @override
  Future<RouteRecord> planCyclingRoute({
    required double originLatitude,
    required double originLongitude,
    required String destination,
  }) async {
    if (!isConfigured) {
      throw StateError('Layanan rute online belum dikonfigurasi.');
    }
    if (!originLatitude.isFinite ||
        originLatitude < -90 ||
        originLatitude > 90 ||
        !originLongitude.isFinite ||
        originLongitude < -180 ||
        originLongitude > 180) {
      throw const FormatException('Lokasi awal tidak valid.');
    }
    final normalizedDestination = destination.trim();
    if (normalizedDestination.length < 2 ||
        normalizedDestination.length > 200) {
      throw const FormatException(
        'Masukkan tujuan yang valid (maks. 200 karakter).',
      );
    }

    late final FunctionResponse response;
    try {
      response = await sessionManager.invokeAuthenticatedFunction(
        'cycling-route',
        body: {
          'origin': {
            'latitude': originLatitude,
            'longitude': originLongitude,
          },
          'destination': normalizedDestination,
        },
      );
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map ? details['error'] : null;
      if (message is String && message.trim().isNotEmpty) {
        throw StateError(message.trim());
      }
      throw StateError(
        switch (error.status) {
          401 || 403 => 'Masuk ke akun online untuk mencari rute.',
          404 => 'Layanan pencarian rute belum dipasang di Supabase.',
          429 =>
            'Terlalu banyak pencarian rute. Tunggu sebentar lalu coba lagi.',
          503 => 'Google Maps Directions belum dikonfigurasi di server.',
          _ => 'Pencarian rute gagal (HTTP ${error.status}).',
        },
      );
    }
    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final message = data is Map ? data['error'] : null;
      throw StateError(
        message is String && message.isNotEmpty
            ? message
            : 'Pencarian rute gagal (HTTP ${response.status}).',
      );
    }
    final data = response.data;
    if (data is! Map ||
        data['name'] is! String ||
        data['distanceMeters'] is! num ||
        data['durationSeconds'] is! num ||
        data['points'] is! List) {
      throw const FormatException('Respons rute Google Maps tidak valid.');
    }
    final points = <RoutePoint>[];
    for (final item in data['points'] as List) {
      if (item is! Map ||
          item['latitude'] is! num ||
          item['longitude'] is! num) {
        throw const FormatException('Geometri rute Google Maps tidak valid.');
      }
      final latitude = (item['latitude'] as num).toDouble();
      final longitude = (item['longitude'] as num).toDouble();
      if (!latitude.isFinite ||
          latitude < -90 ||
          latitude > 90 ||
          !longitude.isFinite ||
          longitude < -180 ||
          longitude > 180) {
        throw const FormatException('Koordinat rute Google Maps tidak valid.');
      }
      points.add(
        RoutePoint(
          latitude: latitude,
          longitude: longitude,
          elevationMeters: 0,
        ),
      );
    }
    final distanceMeters = (data['distanceMeters'] as num).toDouble();
    final durationSeconds = (data['durationSeconds'] as num).toInt();
    if (points.length < 2 ||
        !distanceMeters.isFinite ||
        distanceMeters <= 0 ||
        durationSeconds < 0 ||
        durationSeconds > 7 * 24 * 60 * 60) {
      throw const FormatException('Data rute Google Maps tidak valid.');
    }
    return RouteRecord(
      id: 'google-${DateTime.now().microsecondsSinceEpoch}',
      name: data['name'] as String,
      source: 'Google Maps · bersepeda',
      updatedAt: DateTime.now().toUtc(),
      availability: 'online',
      description:
          'Estimasi ${_formatDuration(durationSeconds)} · rute online',
      distanceMeters: distanceMeters,
      points: points,
    );
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).ceil();
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return hours == 0 ? '$minutes menit' : '$hours jam $remainingMinutes menit';
  }
}
