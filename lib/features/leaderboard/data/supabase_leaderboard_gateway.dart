import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/data/custom_auth_session_manager.dart';
import '../domain/leaderboard_models.dart';
import 'leaderboard_gateway.dart';

class SupabaseLeaderboardGateway implements LeaderboardGateway {
  const SupabaseLeaderboardGateway(this._client, this._sessionManager);

  final SupabaseClient? _client;
  final CustomAuthSessionManager _sessionManager;

  @override
  bool get isConfigured => _client != null;

  @override
  bool get isSignedIn => _sessionManager.currentUserId != null;

  Future<SupabaseClient> get _requiredClient async {
    final client = _client;
    if (client == null || _sessionManager.currentUserId == null) {
      throw StateError('Masuk ke akun online untuk menggunakan leaderboard.');
    }
    await _sessionManager.requireAccessToken();
    return client;
  }

  @override
  Future<LeaderboardSettings> loadSettings() async {
    final response = await (await _requiredClient).rpc(
      'get_leaderboard_settings',
    );
    final row = _singleRow(response);
    return LeaderboardSettings(
      isOptedIn: row['is_opted_in'] == true,
      alias: row['public_alias'] as String?,
    );
  }

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
            alias: row['public_alias'] as String,
            score: (row['score'] as num).toDouble(),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> saveConsent({
    required String alias,
    required bool isOptedIn,
  }) async {
    await (await _requiredClient).rpc(
      'set_leaderboard_consent',
      params: {'p_public_alias': alias, 'p_is_opted_in': isOptedIn},
    );
  }

  @override
  Future<void> submitSession(String sessionId) async {
    await (await _requiredClient).rpc(
      'submit_leaderboard_ride',
      params: {'p_session_id': sessionId},
    );
  }

  Map<String, Object?> _singleRow(Object? response) {
    if (response is! List || response.isEmpty || response.first is! Map) {
      throw const FormatException('Pengaturan leaderboard tidak tersedia.');
    }
    return Map<String, Object?>.from(response.first as Map);
  }
}
