import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/storage/secure_vault.dart';

class CustomAuthSessionManager {
  CustomAuthSessionManager({
    required this._client,
    required this._secureVault,
  });

  static const _storageKey = 'custom_auth_session';
  final SupabaseClient? _client;
  final SecureVault _secureVault;
  final StreamController<String?> _authChanges =
      StreamController<String?>.broadcast();
  _AuthSession? _session;
  Future<void>? _refreshInFlight;

  bool get isConfigured => _client != null;
  String? get currentEmail => isConfigured ? _session?.email : null;
  String? get currentUserId => isConfigured ? _session?.userId : null;
  Stream<String?> get authChanges => _authChanges.stream;

  Future<bool> get hasStoredSession async =>
      (await _secureVault.read(_storageKey)) != null;

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

  Future<void> restoreForBiometricSignIn() async {
    await restore();
    if (_session == null) {
      throw StateError(
        'Tidak ada sesi akun tersimpan. Masuk dengan email dan password terlebih dahulu.',
      );
    }
    try {
      await requireAccessToken();
    } catch (_) {
      _session = null;
      _client?.rest.setAuth(null);
      rethrow;
    }
    _authChanges.add(_session!.email);
  }

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

  Future<String> requireAccessToken() async {
    final session = _session;
    if (session == null) {
      throw StateError('Masuk ke akun online untuk melanjutkan.');
    }
    if (session.expiresAt.isAfter(
      DateTime.now().toUtc().add(const Duration(seconds: 60)),
    )) {
      return session.accessToken;
    }
    await _refreshSession();
    final refreshed = _session;
    if (refreshed == null) {
      throw StateError('Sesi berakhir. Silakan masuk kembali.');
    }
    return refreshed.accessToken;
  }

  Future<void> signOut() async {
    final session = _session;
    if (session == null) return;
    await _invokeAuth('sign-out', {'refreshToken': session.refreshToken});
    await _clearSession();
  }

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

  Future<void> _refreshSession() async {
    final existing = _refreshInFlight;
    if (existing != null) {
      await existing;
      return;
    }
    final future = _performRefresh();
    _refreshInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    }
  }

  Future<void> _performRefresh() async {
    final session = _session;
    if (session == null) {
      throw StateError('Masuk ke akun online untuk melanjutkan.');
    }
    try {
      await authenticate('refresh', values: {
        'refreshToken': session.refreshToken,
      });
    } on CustomAuthException catch (error) {
      if (error.status == 401) await _clearSession();
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  Future<Map<String, Object?>> _invokeAuth(
    String action,
    Map<String, Object?> values,
  ) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase belum dikonfigurasi.');
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
        throw const CustomAuthException(
          status: 404,
          message:
              'Edge Function app-auth belum tersedia. Deploy dengan `supabase functions deploy app-auth`.',
        );
      }
      throw CustomAuthException(
        status: error.status,
        message: switch (message) {
          String value when value.isNotEmpty => value,
          _ => 'Autentikasi gagal (HTTP ${error.status}). Periksa konfigurasi Supabase Edge Function.',
        },
      );
    }
    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final message = data is Map ? data['error'] : null;
      throw CustomAuthException(
        status: response.status,
        message: message is String && message.isNotEmpty
            ? message
            : 'Autentikasi gagal (HTTP ${response.status}).',
      );
    }
    if (response.data is! Map) {
      throw const FormatException('Respons autentikasi tidak valid.');
    }
    return Map<String, Object?>.from(response.data as Map);
  }

  Future<void> _acceptSession(Map<String, Object?> response) async {
    final session = _AuthSession.fromJson(response);
    await _secureVault.write(_storageKey, jsonEncode(session.toJson()));
    _session = session;
    _client?.rest.setAuth(session.accessToken);
    _authChanges.add(session.email);
  }

  Future<void> _clearSession() async {
    _session = null;
    _client?.rest.setAuth(null);
    await _secureVault.delete(_storageKey);
    _authChanges.add(null);
  }

  SupabaseClient get _requiredClient =>
      _client ?? (throw StateError('Supabase belum dikonfigurasi.'));

  Future<void> dispose() => _authChanges.close();
}

class CustomAuthException implements Exception {
  const CustomAuthException({required this.status, required this.message});

  final int status;
  final String message;

  @override
  String toString() => message;
}

class _AuthSession {
  const _AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
    required this.expiresAt,
  });

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

  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'user': {'id': userId, 'email': email},
    'expiresAt': expiresAt.millisecondsSinceEpoch,
  };
}
