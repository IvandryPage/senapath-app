import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/data/custom_auth_session_manager.dart';
import '../../gamification/domain/rider_progress.dart';
import '../../session/domain/ride_session.dart';
import 'account_cloud_gateway.dart';

class SupabaseAccountCloudGateway implements AccountCloudGateway {
  /// Membuat gateway penyimpanan akun cloud Supabase.
  const SupabaseAccountCloudGateway(this._client, this._sessionManager);

  static const int _telemetryBatchSize = 500;

  final SupabaseClient? _client;
  final CustomAuthSessionManager _sessionManager;

  /// Menentukan apakah klien Supabase tersedia.
  @override
  bool get isConfigured => _client != null;

  /// Menentukan apakah pengguna telah masuk.
  @override
  bool get isSignedIn => _sessionManager.currentUserId != null;

  /// Membaca dokumen pengaturan JSON milik akun.
  @override
  Future<Object?> pullSetting(String key) async {
    final client = _requiredClient();
    final userId = await _requireUserId();
    final row = await client
        .from('account_settings')
        .select('value')
        .eq('user_id', userId)
        .eq('key', key)
        .maybeSingle();
    return row?['value'];
  }

  /// Menyimpan dokumen pengaturan JSON milik akun.
  @override
  Future<void> pushSetting(String key, Object? value) async {
    final client = _requiredClient();
    final userId = await _requireUserId();
    await client.from('account_settings').upsert({
      'user_id': userId,
      'key': key,
      'value': value,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,key');
  }

  /// Menyimpan sesi dan telemetri secara bertahap ke cloud.
  @override
  Future<void> pushRideSession(
    RideSessionSnapshot session,
    List<TelemetryLocation> points,
  ) async {
    final client = _requiredClient();
    final userId = await _requireUserId();
    final endedAt = session.endedAt;
    if (endedAt == null) {
      throw StateError('Waktu selesai sesi tidak tersedia.');
    }

    await client.from('ride_sessions').upsert({
      'user_id': userId,
      'session_id': session.id,
      'title': session.title,
      'activity_type': session.activityType.name,
      'source': session.source,
      'started_at': session.startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt.toUtc().toIso8601String(),
      'total_paused_ms': session.totalPausedMilliseconds,
      'distance_meters': session.distanceMeters,
      'gps_accuracy_meters': session.gpsAccuracyMeters,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,session_id');

    await client
        .from('ride_session_telemetry')
        .delete()
        .eq('user_id', userId)
        .eq('session_id', session.id);

    for (
      var offset = 0;
      offset < points.length;
      offset += _telemetryBatchSize
    ) {
      final end = (offset + _telemetryBatchSize).clamp(0, points.length);
      final batch = <Map<String, Object?>>[];
      for (var index = offset; index < end; index++) {
        batch.add(_telemetryRow(userId, session.id, index, points[index]));
      }
      if (batch.isNotEmpty) {
        await client.from('ride_session_telemetry').insert(batch);
      }
    }
  }

  /// Menyusun satu baris telemetri untuk disimpan.
  Map<String, Object?> _telemetryRow(
    String userId,
    String sessionId,
    int pointIndex,
    TelemetryLocation point,
  ) => {
    'user_id': userId,
    'session_id': sessionId,
    'point_index': pointIndex,
    'recorded_at': point.recordedAt.toUtc().toIso8601String(),
    'latitude': point.latitude,
    'longitude': point.longitude,
    'accuracy_meters': point.accuracyMeters,
    'altitude_meters': point.altitudeMeters,
    'altitude_accuracy_meters': point.altitudeAccuracyMeters,
    'barometric_pressure_hpa': point.barometricPressureHpa,
    'acceleration_magnitude': point.accelerationMagnitudeMetersPerSecondSquared,
    'rotation_rate_magnitude': point.rotationRateMagnitudeRadiansPerSecond,
    'speed_meters_per_second': point.speedMetersPerSecond,
  };

  /// Mengambil sesi beserta telemetri yang diurutkan.
  @override
  Future<List<CloudRideSession>> pullRideSessions() async {
    final client = _requiredClient();
    final userId = await _requireUserId();
    final sessionRows = await client
        .from('ride_sessions')
        .select()
        .eq('user_id', userId)
        .order('started_at');
    if (sessionRows.isEmpty) return const [];

    final pointsBySession = <String, List<TelemetryLocation>>{};
    final sessionIds = sessionRows
        .map((row) => row['session_id'] as String)
        .toList(growable: false);
    final pointRows = await client
        .from('ride_session_telemetry')
        .select()
        .eq('user_id', userId)
        .inFilter('session_id', sessionIds)
        .order('session_id')
        .order('point_index');
    for (final row in pointRows) {
      final sessionId = row['session_id'] as String;
      (pointsBySession[sessionId] ??= <TelemetryLocation>[]).add(
        _telemetryFromRow(row),
      );
    }

    return [
      for (final row in sessionRows)
        CloudRideSession(
          session: _sessionFromRow(row),
          points: pointsBySession[row['session_id'] as String] ?? const [],
        ),
    ];
  }

  /// Membangun snapshot sesi dari baris database.
  RideSessionSnapshot _sessionFromRow(Map<String, dynamic> row) {
    final startedAt = DateTime.parse(row['started_at'] as String).toUtc();
    final endedAt = DateTime.parse(row['ended_at'] as String).toUtc();
    return RideSessionSnapshot(
      id: row['session_id'] as String,
      title: row['title'] as String? ?? '',
      activityType: _activityTypeFromName(row['activity_type'] as String?),
      source: row['source'] as String? ?? 'recorded',
      startedAt: startedAt,
      endedAt: endedAt,
      status: RideSessionStatus.completed,
      totalPausedMilliseconds: (row['total_paused_ms'] as num?)?.toInt() ?? 0,
      distanceMeters: (row['distance_meters'] as num).toDouble(),
      currentSpeedMetersPerSecond: 0,
      syncStatus: 'synced',
      gpsAccuracyMeters: (row['gps_accuracy_meters'] as num?)?.toDouble(),
    );
  }

  /// Membangun titik telemetri dari baris database.
  TelemetryLocation _telemetryFromRow(
    Map<String, dynamic> row,
  ) => TelemetryLocation(
    recordedAt: DateTime.parse(row['recorded_at'] as String).toUtc(),
    latitude: (row['latitude'] as num).toDouble(),
    longitude: (row['longitude'] as num).toDouble(),
    accuracyMeters: (row['accuracy_meters'] as num).toDouble(),
    altitudeMeters: (row['altitude_meters'] as num).toDouble(),
    altitudeAccuracyMeters: (row['altitude_accuracy_meters'] as num?)
        ?.toDouble(),
    barometricPressureHpa: (row['barometric_pressure_hpa'] as num?)?.toDouble(),
    accelerationMagnitudeMetersPerSecondSquared:
        (row['acceleration_magnitude'] as num?)?.toDouble(),
    rotationRateMagnitudeRadiansPerSecond:
        (row['rotation_rate_magnitude'] as num?)?.toDouble(),
    speedMetersPerSecond: (row['speed_meters_per_second'] as num).toDouble(),
  );

  /// Menghapus sesi dan telemetrinya dari cloud.
  @override
  Future<void> deleteRideSession(String sessionId) async {
    final client = _requiredClient();
    final userId = await _requireUserId();
    await client
        .from('ride_session_telemetry')
        .delete()
        .eq('user_id', userId)
        .eq('session_id', sessionId);
    await client
        .from('ride_sessions')
        .delete()
        .eq('user_id', userId)
        .eq('session_id', sessionId);
  }

  /// Menyimpan progres pengendara melalui RPC.
  @override
  Future<void> pushRiderProgress({
    required RiderStyle style,
    required int level,
    required int experience,
    required double distanceMeters,
    required int completedRides,
    required int rideDurationSeconds,
    required int weekendRides,
    required RiderAppearance appearance,
  }) async {
    final client = _requiredClient();
    await _requireUserId();
    await client.rpc(
      'set_my_rider_progress',
      params: {
        'p_rider_style': style.name,
        'p_rider_level': level,
        'p_experience': experience,
        'p_distance_meters': distanceMeters,
        'p_completed_rides': completedRides,
        'p_ride_duration_seconds': rideDurationSeconds,
        'p_weekend_rides': weekendRides,
        'p_appearance': appearance.toJson(),
      },
    );
  }

  /// Mengambil progres pengendara, atau null bila belum ada.
  @override
  Future<CloudRiderProgress?> pullRiderProgress() async {
    final client = _requiredClient();
    final userId = await _requireUserId();
    final row = await client
        .from('rider_profiles')
        .select(
          'rider_style, rider_level, experience, distance_meters, '
          'completed_rides, ride_duration_seconds, weekend_rides, appearance',
        )
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    final rawAppearance = row['appearance'];
    RiderAppearance? appearance;
    if (rawAppearance is Map) {
      try {
        appearance = RiderAppearance.fromJson(
          Map<String, dynamic>.from(rawAppearance),
        );
      } catch (_) {
        appearance = null;
      }
    }
    return CloudRiderProgress(
      style: RiderStyle.fromName(row['rider_style']),
      level: (row['rider_level'] as num?)?.toInt() ?? 1,
      experience: (row['experience'] as num?)?.toInt() ?? 0,
      distanceMeters: (row['distance_meters'] as num?)?.toDouble() ?? 0,
      completedRides: (row['completed_rides'] as num?)?.toInt() ?? 0,
      rideDurationSeconds: (row['ride_duration_seconds'] as num?)?.toInt() ?? 0,
      weekendRides: (row['weekend_rides'] as num?)?.toInt() ?? 0,
      appearance: appearance,
    );
  }

  /// Mengembalikan klien Supabase atau melempar error.
  SupabaseClient _requiredClient() {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase belum dikonfigurasi.');
    }
    return client;
  }

  /// Memastikan pengguna masuk dan tokennya valid.
  Future<String> _requireUserId() async {
    final userId = _sessionManager.currentUserId;
    if (userId == null) {
      throw StateError('Masuk ke akun online untuk melanjutkan.');
    }
    await _sessionManager.requireAccessToken();
    return userId;
  }

  /// Memetakan nama aktivitas ke enum, default ride.
  RideActivityType _activityTypeFromName(String? value) => switch (value) {
    'commute' => RideActivityType.commute,
    'training' => RideActivityType.training,
    'race' => RideActivityType.race,
    _ => RideActivityType.ride,
  };
}
