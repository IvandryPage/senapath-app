import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/data/custom_auth_session_manager.dart';
import 'ride_coach_gateway.dart';

class SupabaseRideCoachGateway implements RideCoachGateway {
  const SupabaseRideCoachGateway(this._client, this._sessionManager);

  final SupabaseClient? _client;
  final CustomAuthSessionManager _sessionManager;

  @override
  bool get isConfigured => _client != null;

  @override
  Future<String> recommend({
    required Map<String, Object?> rideContext,
    required bool consent,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Layanan rekomendasi belum dikonfigurasi.');
    }
    if (!consent) {
      throw StateError('Persetujuan pengiriman konteks gowes diperlukan.');
    }
    if (_sessionManager.currentUserId == null) {
      throw StateError('Masuk ke akun sebelum meminta rekomendasi AI.');
    }
    final response = await _sessionManager.invokeAuthenticatedFunction(
      'rider-coach',
      body: {'consent': consent, 'ride': rideContext},
    );
    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final message = data is Map ? data['error'] : null;
      throw StateError(
        message is String && message.isNotEmpty
            ? message
            : 'Layanan rekomendasi gagal (HTTP ${response.status}).',
      );
    }
    final data = response.data;
    final recommendation = data is Map ? data['recommendation'] : null;
    if (recommendation is! String || recommendation.trim().isEmpty) {
      throw const FormatException('Respons rekomendasi AI tidak valid.');
    }
    return recommendation.trim();
  }
}
