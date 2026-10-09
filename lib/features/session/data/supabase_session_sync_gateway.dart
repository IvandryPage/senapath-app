import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/data/custom_auth_session_manager.dart';
import '../domain/ride_session.dart';
import 'session_sync_gateway.dart';

class SupabaseSessionSyncGateway implements SessionSyncGateway {
  const SupabaseSessionSyncGateway(this._client, this._sessionManager);

  final SupabaseClient? _client;
  final CustomAuthSessionManager _sessionManager;

  @override
  bool get isConfigured => _client != null;

  @override
  bool get isSignedIn => _sessionManager.currentUserId != null;

  @override
  Future<void> uploadSummary(
    RideSessionSummary summary, {
    String? shareWithTeamId,
  }) async {
    final client = _client;
    final userId = _sessionManager.currentUserId;
    if (client == null || userId == null) {
      throw StateError('Masuk ke akun online sebelum menyinkronkan sesi.');
    }
    await _sessionManager.requireAccessToken();
    if (summary.session.status != RideSessionStatus.completed) {
      throw StateError('Hanya ringkasan sesi selesai yang dapat disinkronkan.');
    }

    final session = summary.session;
    final endedAt = session.endedAt;
    if (endedAt == null) {
      throw StateError('Waktu selesai sesi tidak tersedia.');
    }

    await client.from('ride_session_summaries').upsert({
      'user_id': userId,
      'session_id': session.id,
      'started_at': session.startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt.toUtc().toIso8601String(),
      'duration_seconds': session.durationAt(endedAt).inSeconds,
      'distance_meters': session.distanceMeters,
      'sample_count': summary.sampleCount,
      'elevation_gain_meters': summary.elevationGainMeters,
      'elevation_source': summary.elevationSource,
      'accelerometer_sample_count': summary.accelerometerSampleCount,
      'gyroscope_sample_count': summary.gyroscopeSampleCount,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,session_id');
    if (shareWithTeamId != null) {
      await client
          .from('team_shared_ride_summaries')
          .upsert(
            {
              'team_id': shareWithTeamId,
              'user_id': userId,
              'session_id': session.id,
            },
            onConflict: 'team_id,user_id,session_id',
            ignoreDuplicates: true,
          );
    }
  }
}
