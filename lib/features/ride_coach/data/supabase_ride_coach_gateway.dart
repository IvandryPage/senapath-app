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
    late final FunctionResponse response;
    try {
      response = await _sessionManager.invokeAuthenticatedFunction(
        'rider-coach',
        body: {'action': 'diagnose'},
      );
    } on FunctionException catch (error) {
      throw StateError(_functionErrorMessage(error));
    }
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
    late final FunctionResponse response;
    try {
      response = await _sessionManager.invokeAuthenticatedFunction(
        'rider-coach',
        body: {'consent': consent, 'ride': rideContext},
      );
    } on FunctionException catch (error) {
      throw StateError(_functionErrorMessage(error));
    }
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

  String _functionErrorMessage(FunctionException error) {
    final details = error.details;
    final message = details is Map ? details['error'] : null;
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    return switch (error.status) {
      401 || 403 => 'Sesi akun tidak valid. Silakan masuk kembali.',
      429 => 'Batas penggunaan rekomendasi AI tercapai. Coba lagi nanti.',
      503 =>
        'Layanan AI belum siap. Periksa konfigurasi Edge Function dan secrets Supabase.',
      _ => 'Edge Function rider-coach gagal (HTTP ${error.status}). Periksa log Supabase Functions.',
    };
  }
}
