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
  bool get isSignedIn => _sessionManager.currentUserId != null;

  @override
  Future<String> diagnoseConfiguration() async {
    if (_client == null) {
      throw StateError('Supabase belum dikonfigurasi di aplikasi.');
    }
    if (!isSignedIn) {
      throw StateError('Masuk ke akun online untuk memeriksa layanan AI.');
    }
    final response = await _sessionManager.invokeAuthenticatedFunction(
      'rider-coach',
      body: {'action': 'diagnose'},
    );
    final data = response.data;
    if (response.status < 200 || response.status >= 300) {
      final message = data is Map ? data['error'] : null;
      throw StateError(
        message is String && message.isNotEmpty
            ? message
            : 'Pemeriksaan gagal (HTTP ${response.status}).',
      );
    }
    if (data is! Map || data['diagnostic'] is! String) {
      throw const FormatException('Respons pemeriksaan Gemini tidak valid.');
    }
    return data['diagnostic'] as String;
  }

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
