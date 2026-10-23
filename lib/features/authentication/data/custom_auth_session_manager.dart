import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/storage/secure_vault.dart';
import '../../../core/errors/errors.dart';

class CustomAuthSessionManager {
  /// Membuat pengelola sesi autentikasi kustom.
  CustomAuthSessionManager({required this._client, required this._secureVault});

  static const _storageKey = 'custom_auth_session';
  final SupabaseClient? _client;
  final SecureVault _secureVault;
  final StreamController<String?> _authChanges =
      StreamController<String?>.broadcast();
  _AuthSession? _session;
  Future<void>? _refreshInFlight;

  /// Menentukan apakah klien Supabase tersedia.
  bool get isConfigured => _client != null;

  /// Email pengguna yang sedang masuk, atau null.
  String? get currentEmail => isConfigured ? _session?.email : null;

  /// ID pengguna yang sedang masuk, atau null.
  String? get currentUserId => isConfigured ? _session?.userId : null;

  /// Aliran perubahan email saat sesi masuk atau keluar.
  Stream<String?> get authChanges => _authChanges.stream;

  /// Menentukan apakah ada sesi tersimpan di vault aman.
  Future<bool> get hasStoredSession async =>
      (await _secureVault.read(_storageKey)) != null;

  /// Memulihkan sesi tersimpan dan memasang token ke klien.
  Future<void> restore() async {
    final stored = await _secureVault.read(_storageKey);
    if (stored == null) return;
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map) throw const FormatException('Invalid auth session');
      _session = _AuthSession.fromJson(Map<String, Object?>.from(decoded));
      _client?.rest.setAuth(_session!.accessToken);
    } on FormatException {
      await _clearSession();
    } on TypeError {
      await _clearSession();
    }
  }

  /// Memulihkan sesi tersimpan atau melempar error bila tidak ada.
  Future<void> restoreRememberedSession() async {
    await restore();
    if (_session == null) {
      throw const AuthError(
        message: 'Tidak ada sesi akun tersimpan. Masuk dengan email dan password terlebih dahulu.',
        statusCode: 401,
        isUnauthorized: true,
      );
    }
    _authChanges.add(_session!.email);
  }

  /// Memanggil aksi autentikasi dan menyimpan sesi bila berhasil.
  Future<Map<String, Object?>> authenticate(
    String action, {
    Map<String, Object?> values = const {},
  }) async {
    final response = await _invokeAuth(action, values);
    if (action == 'register' ||
        action == 'sign-in' ||
        action == 'google' ||
        action == 'refresh') {
      await _acceptSession(response);
    }
    return response;
  }

  /// Mengembalikan access token valid, menyegarkan bila hampir kedaluwarsa.
  Future<String> requireAccessToken() async {
    final session = _session;
    if (session == null) {
      throw const AuthError(
        message: 'Masuk ke akun online untuk melanjutkan.',
        statusCode: 401,
        isUnauthorized: true,
      );
    }
    if (session.expiresAt.isAfter(
      DateTime.now().toUtc().add(const Duration(seconds: 60)),
    )) {
      return session.accessToken;
    }
    await _refreshSession();
    final refreshed = _session;
    if (refreshed == null) {
      throw const AuthError(
        message: 'Sesi berakhir. Silakan masuk kembali.',
        statusCode: 401,
        isUnauthorized: true,
      );
    }
    return refreshed.accessToken;
  }

  /// Mengakhiri sesi aktif dan menghapus data sesi tersimpan.
  Future<void> signOut() async {
    final session = _session;
    if (session == null) return;
    await _invokeAuth('sign-out', {'refreshToken': session.refreshToken});
    await _clearSession();
  }

  /// Memanggil Edge Function dengan header Authorization token.
  Future<FunctionResponse> invokeAuthenticatedFunction(
    String name, {
    required Map<String, Object?> body,
  }) async {
    final token = await requireAccessToken();
    return _requiredClient.functions.invoke(
      name,
      body: body,
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  /// Menyegarkan sesi sambil mencegah penyegaran ganda bersamaan.
  Future<void> _refreshSession() async {
    final existing = _refreshInFlight;
    if (existing != null) {
      // Wait for existing refresh but with timeout protection
      try {
        await existing.timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw const TimeoutError(
            message: 'Token refresh timed out',
            operation: 'refresh_session',
            duration: Duration(seconds: 30),
          ),
        );
      } catch (_) {
        // If existing refresh failed, allow retry
        if (identical(_refreshInFlight, existing)) _refreshInFlight = null;
        rethrow;
      }
      return;
    }
    final future = _performRefresh();
    _refreshInFlight = future;
    try {
      await future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw const TimeoutError(
          message: 'Token refresh timed out',
          operation: 'refresh_session',
          duration: Duration(seconds: 30),
        ),
      );
    } finally {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    }
  }

  /// Melakukan penyegaran token dan menghapus sesi bila ditolak.
  Future<void> _performRefresh() async {
    final session = _session;
    if (session == null) {
      throw const AuthError(
        message: 'Masuk ke akun online untuk melanjutkan.',
        statusCode: 401,
        isUnauthorized: true,
      );
    }
    try {
      await authenticate(
        'refresh',
        values: {'refreshToken': session.refreshToken},
      );
    } on CustomAuthException catch (error) {
      if (error.status == 401) await _clearSession();
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  /// Memanggil fungsi app-auth dan menerjemahkan error HTTP.
  Future<Map<String, Object?>> _invokeAuth(
    String action,
    Map<String, Object?> values,
  ) async {
    final client = _client;
    if (client == null) {
      throw const ConfigurationError(
        message: 'Supabase belum dikonfigurasi.',
        configKey: 'SUPABASE_URL',
      );
    }
    late final FunctionResponse response;
    try {
      response = await client.functions.invoke(
        'app-auth',
        body: {'action': action, ...values},
      );
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map ? details['error'] : null;
      if (error.status == 404) {
        throw const ConfigurationError(
          message: 'Edge Function app-auth belum tersedia. Deploy dengan `supabase functions deploy app-auth`.',
          configKey: 'app-auth',
        );
      }
      throw AuthError(
        statusCode: error.status,
        message: switch (message) {
          String value when value.isNotEmpty => value,
          _ =>
            'Autentikasi gagal (HTTP ${error.status}). Periksa konfigurasi Supabase Edge Function.',
        },
        isUnauthorized: error.status == 401,
      );
    }
    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final message = data is Map ? data['error'] : null;
      throw AuthError(
        statusCode: response.status,
        message: message is String && message.isNotEmpty
            ? message
            : 'Autentikasi gagal (HTTP ${response.status}).',
        isUnauthorized: response.status == 401,
      );
    }
    if (response.data is! Map) {
      throw const ValidationError(
        message: 'Respons autentikasi tidak valid.',
        field: 'response.data',
      );
    }
    return Map<String, Object?>.from(response.data as Map);
  }

  /// Menyimpan sesi baru ke vault dan memberi tahu pendengar.
  Future<void> _acceptSession(Map<String, Object?> response) async {
    final session = _AuthSession.fromJson(response);
    await _secureVault.write(_storageKey, jsonEncode(session.toJson()));
    _session = session;
    _client?.rest.setAuth(session.accessToken);
    _authChanges.add(session.email);
  }

  /// Menghapus sesi aktif, token klien, dan data tersimpan.
  Future<void> _clearSession() async {
    _session = null;
    _client?.rest.setAuth(null);
    await _secureVault.delete(_storageKey);
    _authChanges.add(null);
  }

  /// Mengembalikan klien Supabase atau melempar error bila belum dikonfigurasi.
  SupabaseClient get _requiredClient =>
      _client ?? (throw StateError('Supabase belum dikonfigurasi.'));

  /// Menutup aliran perubahan autentikasi.
  Future<void> dispose() => _authChanges.close();
}

class CustomAuthException implements Exception {
  /// Membuat pengecualian autentikasi dengan status HTTP.
  const CustomAuthException({required this.status, required this.message});

  final int status;
  final String message;

  /// Mengembalikan pesan error sebagai teks.
  @override
  String toString() => message;
}

class _AuthSession {
  /// Membuat data sesi autentikasi.
  const _AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
    required this.expiresAt,
  });

  /// Membuat sesi dari JSON dan memvalidasi semua kolom wajib.
  factory _AuthSession.fromJson(Map<String, Object?> json) {
    final user = json['user'];
    if (user is! Map) throw const FormatException('Missing auth user');
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];
    final userId = user['id'];
    final email = user['email'];
    final expiresAt = json['expiresAt'];
    if (accessToken is! String ||
        refreshToken is! String ||
        userId is! String ||
        email is! String ||
        expiresAt is! num) {
      throw const FormatException('Invalid auth session values');
    }
    return _AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      email: email,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        expiresAt.toInt(),
        isUtc: true,
      ),
    );
  }

  final String accessToken;
  final String refreshToken;
  final String userId;
  final String email;
  final DateTime expiresAt;

  /// Mengonversi sesi ke bentuk JSON untuk disimpan.
  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'user': {'id': userId, 'email': email},
    'expiresAt': expiresAt.millisecondsSinceEpoch,
  };
}
