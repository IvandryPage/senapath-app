import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/data/custom_auth_session_manager.dart';
import 'ride_coach_gateway.dart';

class SupabaseRideCoachGateway implements RideCoachGateway {
  /// Membuat gateway dengan klien Supabase dan manajer sesi autentikasi.
  const SupabaseRideCoachGateway(this._client, this._sessionManager);

  final SupabaseClient? _client;
  final CustomAuthSessionManager _sessionManager;

  /// Menandakan klien Supabase tersedia.
  @override
  bool get isConfigured => _client != null;

  /// Menandakan pengguna memiliki sesi akun aktif.
  @override
  bool get isSignedIn => _sessionManager.currentUserId != null;

  /// Memanggil Edge Function untuk memeriksa kesiapan layanan AI.
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

  /// Meminta rekomendasi AI dan memvalidasi respons dari Edge Function.
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

  /// Meminta briefing pra-perjalanan dan memvalidasi respons AI.
  @override
  Future<String> prepareRide({
    required Map<String, Object?> routeAndWeather,
    required bool consent,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Layanan briefing belum dikonfigurasi.');
    }
    if (!consent) {
      throw StateError('Persetujuan briefing pra-perjalanan diperlukan.');
    }
    if (_sessionManager.currentUserId == null) {
      throw StateError('Masuk ke akun sebelum meminta briefing AI.');
    }
    late final FunctionResponse response;
    try {
      response = await _sessionManager.invokeAuthenticatedFunction(
        'rider-coach',
        body: {
          'action': 'pre_ride',
          'consent': consent,
          'preRide': routeAndWeather,
        },
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
            : 'Layanan briefing gagal (HTTP ${response.status}).',
      );
    }
    final data = response.data;
    final briefing = data is Map ? data['briefing'] : null;
    if (briefing is! String || briefing.trim().isEmpty) {
      throw const FormatException('Respons briefing AI tidak valid.');
    }
    return briefing.trim();
  }

  /// Menyusun pesan kesalahan yang ramah dari kegagalan Edge Function.
  String _functionErrorMessage(FunctionException error) {
    final details = error.details;
    final message = details is Map ? details['error'] : null;
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    return switch (error.status) {
      401 || 403 => 'Sesi akun tidak valid. Silakan masuk kembali.',
      429 => 'Batas penggunaan rekomendasi AI tercapai. Coba lagi nanti.',
      503 => 'Layanan AI belum siap. Periksa konfigurasi Edge Function dan secrets Supabase.',
      _ =>
        'Edge Function rider-coach gagal (HTTP ${error.status}). Periksa log Supabase Functions.',
    };
  }
}
