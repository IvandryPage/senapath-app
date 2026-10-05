import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/device_authenticator.dart';
import '../data/cloud_account_gateway.dart';
import '../data/custom_auth_session_manager.dart';

class CloudAccountState {
  const CloudAccountState({
    this.email,
    this.isConfigured = false,
    this.isLoading = false,
    this.canUseBiometrics = false,
    this.status,
    this.error,
  });

  final String? email;
  final bool isConfigured;
  final bool isLoading;
  final bool canUseBiometrics;
  final String? status;
  final String? error;

  bool get isSignedIn => email != null;

  CloudAccountState copyWith({
    String? email,
    bool? isConfigured,
    bool? isLoading,
    bool? canUseBiometrics,
    String? status,
    String? error,
    bool clearEmail = false,
    bool clearStatus = false,
    bool clearError = false,
  }) => CloudAccountState(
    email: clearEmail ? null : email ?? this.email,
    isConfigured: isConfigured ?? this.isConfigured,
    isLoading: isLoading ?? this.isLoading,
    canUseBiometrics: canUseBiometrics ?? this.canUseBiometrics,
    status: clearStatus ? null : status ?? this.status,
    error: clearError ? null : error ?? this.error,
  );
}

class CloudAccountCubit extends Cubit<CloudAccountState> {
  CloudAccountCubit(this._gateway, {this.authenticator})
    : super(
        CloudAccountState(
          isConfigured: _gateway.isConfigured,
          email: _gateway.currentEmail,
        ),
      );

  final CloudAccountGateway _gateway;
  final DeviceAuthenticator? authenticator;
  StreamSubscription<String?>? _authSubscription;

  void initialize() {
    if (_authSubscription != null || !_gateway.isConfigured) return;
    _authSubscription = _gateway.authChanges.listen((email) {
      if (isClosed) return;
      emit(
        state.copyWith(
          email: email,
          clearEmail: email == null,
          clearError: true,
        ),
      );
    });
    _loadBiometricAvailability();
  }

  Future<void> _loadBiometricAvailability() async {
    final authenticator = this.authenticator;
    if (authenticator == null) return;
    try {
      final rememberedSession = await _gateway.hasRememberedSession;
      final biometricsAvailable = await authenticator.hasEnrolledBiometrics;
      if (isClosed) return;
      emit(
        state.copyWith(
          canUseBiometrics: rememberedSession && biometricsAvailable,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          canUseBiometrics: false,
          status: 'Login biometrik tidak tersedia saat ini.',
        ),
      );
    }
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    if (state.isLoading) return;
    final normalizedEmail = email.trim();
    final validationError = _validate(normalizedEmail, password);
    if (validationError != null) {
      emit(state.copyWith(error: validationError, clearStatus: true));
      return;
    }
    if (!_gateway.isConfigured) {
      emit(
        state.copyWith(
          error:
              'Akun online belum tersedia karena Supabase belum dikonfigurasi.',
          clearStatus: true,
        ),
      );
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true, clearStatus: true));
    try {
      final result = await _gateway.register(
        email: normalizedEmail,
        password: password,
      );
      emit(
        state.copyWith(
          email: result.hasSession
              ? (_gateway.currentEmail ?? normalizedEmail)
              : null,
          clearEmail: !result.hasSession,
          isLoading: false,
          status: result.hasSession
              ? 'Akun berhasil dibuat. Kamu sudah masuk.'
              : 'Akun berhasil dibuat.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          error: _messageFor(
            error,
            'Pendaftaran gagal. Periksa email dan koneksi internet.',
          ),
        ),
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    if (state.isLoading) return;
    final normalizedEmail = email.trim();
    final validationError = _validate(normalizedEmail, password);
    if (validationError != null) {
      emit(state.copyWith(error: validationError, clearStatus: true));
      return;
    }
    if (!_gateway.isConfigured) {
      emit(
        state.copyWith(
          error:
              'Akun online belum tersedia karena Supabase belum dikonfigurasi.',
          clearStatus: true,
        ),
      );
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true, clearStatus: true));
    try {
      await _gateway.signIn(email: normalizedEmail, password: password);
      emit(
        state.copyWith(
          email: _gateway.currentEmail ?? normalizedEmail,
          isLoading: false,
          status: 'Berhasil masuk ke akun online.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          error: _messageFor(
            error,
            'Tidak dapat masuk. Periksa email, password, dan koneksi internet.',
          ),
        ),
      );
    }
  }

  Future<void> signInWithBiometrics() async {
    if (state.isLoading) return;
    final authenticator = this.authenticator;
    if (authenticator == null || !state.canUseBiometrics) {
      emit(
        state.copyWith(
          error:
              'Login biometrik belum tersedia. Masuk dengan email dan password terlebih dahulu.',
          clearStatus: true,
        ),
      );
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true, clearStatus: true));
    try {
      final authenticated = await authenticator.authenticate(
        biometricOnly: true,
      );
      if (!authenticated) {
        emit(
          state.copyWith(
            isLoading: false,
            error: 'Autentikasi biometrik dibatalkan atau tidak berhasil.',
          ),
        );
        return;
      }
      await _gateway.signInWithRememberedSession();
      emit(
        state.copyWith(
          email: _gateway.currentEmail,
          isLoading: false,
          canUseBiometrics: false,
          status: 'Berhasil masuk ke akun online dengan biometrik.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          error: _messageFor(
            error,
            'Login biometrik gagal. Masuk dengan email dan password.',
          ),
        ),
      );
    }
  }

  Future<void> sendPasswordReset(String email) async {
    if (state.isLoading) return;
    final normalizedEmail = email.trim();
    if (!_isValidEmail(normalizedEmail)) {
      emit(state.copyWith(error: 'Masukkan alamat email yang valid.'));
      return;
    }
    if (!_gateway.isConfigured) {
      emit(
        state.copyWith(
          error: 'Pemulihan akun belum tersedia karena Supabase belum dikonfigurasi.',
        ),
      );
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true, clearStatus: true));
    try {
      await _gateway.sendPasswordReset(normalizedEmail);
      emit(
        state.copyWith(
          isLoading: false,
          status: 'Jika email terdaftar, tautan pemulihan akan dikirim.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          error: _messageFor(
            error,
            'Tautan pemulihan tidak dapat dikirim. Periksa koneksi dan konfigurasi email.',
          ),
        ),
      );
    }
  }

  Future<void> completePasswordReset({
    required String token,
    required String password,
  }) async {
    if (state.isLoading) return;
    if (token.isEmpty || password.length < 8 || password.length > 128) {
      emit(
        state.copyWith(
          error:
              'Tautan reset tidak valid atau password tidak memenuhi batas 8-128 karakter.',
          clearStatus: true,
        ),
      );
      return;
    }
    if (!_gateway.isConfigured) {
      emit(
        state.copyWith(
          error: 'Pemulihan akun belum tersedia karena Supabase belum dikonfigurasi.',
          clearStatus: true,
        ),
      );
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true, clearStatus: true));
    try {
      await _gateway.completePasswordReset(token: token, password: password);
      emit(
        state.copyWith(
          isLoading: false,
          status: 'Password berhasil diperbarui. Silakan masuk kembali.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          error: _messageFor(
            error,
            'Password tidak dapat diperbarui. Minta tautan reset yang baru.',
          ),
        ),
      );
    }
  }

  Future<void> signOut() async {
    if (!_gateway.isConfigured || state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearError: true, clearStatus: true));
    try {
      await _gateway.signOut();
      emit(
        state.copyWith(
          clearEmail: true,
          isLoading: false,
          canUseBiometrics: false,
          status:
              'Berhasil keluar dari akun online. Data lokal tetap tersimpan.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          error: _messageFor(
            error,
            'Keluar dari akun online gagal. Coba lagi saat jaringan tersedia.',
          ),
        ),
      );
    }
  }

  String? _validate(String email, String password) {
    if (!_isValidEmail(email)) return 'Masukkan alamat email yang valid.';
    if (password.length < 8) return 'Password harus berisi minimal 8 karakter.';
    if (password.length > 128) return 'Password maksimal 128 karakter.';
    return null;
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  String _messageFor(Object error, String fallback) => switch (error) {
    CustomAuthException(:final message) => message,
    StateError(:final message) => message.toString(),
    _ => fallback,
  };

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    return super.close();
  }
}
