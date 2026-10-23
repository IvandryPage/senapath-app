import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/data/custom_auth_session_manager.dart';
import '../../gamification/domain/rider_progress.dart';
import '../domain/leaderboard_models.dart';
import 'leaderboard_gateway.dart';

class SupabaseLeaderboardGateway implements LeaderboardGateway {
  /// Membuat gateway leaderboard berbasis Supabase dengan manajer sesi.
  const SupabaseLeaderboardGateway(this._client, this._sessionManager);

  final SupabaseClient? _client;
  final CustomAuthSessionManager _sessionManager;

  /// Menandakan klien Supabase tersedia untuk mengakses leaderboard.
  @override
  bool get isConfigured => _client != null;

  /// Menandakan pengguna memiliki sesi akun online aktif.
  @override
  bool get isSignedIn => _sessionManager.currentUserId != null;

  /// Mengembalikan klien Supabase yang siap dipakai setelah memastikan sesi.
  Future<SupabaseClient> get _requiredClient async {
    final client = _client;
    if (client == null || _sessionManager.currentUserId == null) {
      throw StateError('Masuk ke akun online untuk menggunakan leaderboard.');
    }
    await _sessionManager.requireAccessToken();
    return client;
  }

  /// Mengambil pengaturan leaderboard pengguna melalui RPC Supabase.
  @override
  Future<LeaderboardSettings> loadSettings() async {
    final response = await (await _requiredClient).rpc(
      'get_leaderboard_settings',
    );
    final row = _singleRow(response);
    return LeaderboardSettings(
      isOptedIn: row['is_opted_in'] == true,
      displayName: row['display_name'] as String?,
    );
  }

  /// Mengambil daftar peringkat kategori tertentu dan memetakannya ke model.
  @override
  Future<List<LeaderboardEntry>> loadEntries(
    LeaderboardCategory category,
  ) async {
    final response = await (await _requiredClient).rpc(
      'get_weekly_cycling_leaderboard',
      params: {'p_category': category.name},
    );
    if (response is! List) {
      throw const FormatException('Respons leaderboard tidak valid.');
    }
    return response
        .map((raw) {
          if (raw is! Map) {
            throw const FormatException('Baris leaderboard tidak valid.');
          }
          final row = Map<String, Object?>.from(raw);
          return LeaderboardEntry(
            rank: (row['place'] as num).toInt(),
            displayName: row['display_name'] as String,
            score: (row['score'] as num).toDouble(),
            riderLevel: (row['rider_level'] as num?)?.toInt() ?? 1,
            riderStyle: RiderStyle.fromName(row['rider_style']),
            riderExperience: (row['experience'] as num?)?.toInt() ?? 0,
          );
        })
        .toList(growable: false);
  }

  /// Menyimpan pilihan keikutsertaan leaderboard melalui RPC Supabase.
  @override
  Future<void> saveConsent({required bool isOptedIn}) async {
    await (await _requiredClient).rpc(
      'set_leaderboard_consent',
      params: {'p_is_opted_in': isOptedIn},
    );
  }

  /// Mengirim rekor durasi dan jarak terbaik melalui RPC Supabase.
  @override
  Future<void> recordPersonalBest({
    required int durationSeconds,
    required double distanceMeters,
  }) async {
    await (await _requiredClient).rpc(
      'record_my_leaderboard_ride',
      params: {
        'p_duration_seconds': durationSeconds,
        'p_distance_meters': distanceMeters,
      },
    );
  }

  /// Mengambil satu baris hasil RPC dan melempar error bila formatnya salah.
  Map<String, Object?> _singleRow(Object? response) {
    if (response is! List || response.isEmpty || response.first is! Map) {
      throw const FormatException('Pengaturan leaderboard tidak tersedia.');
    }
    return Map<String, Object?>.from(response.first as Map);
  }
}
