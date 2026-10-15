import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/device_authenticator.dart';
import '../data/cloud_account_gateway.dart';
import '../data/custom_auth_session_manager.dart';
import '../data/biometric_sign_in_settings_repository.dart';

class CloudAccountState {
  const CloudAccountState({
    this.email,
    this.isConfigured = false,
    this.isInitialized = false,
    this.isInitializing = false,
    this.isLoading = false,
    this.canUseBiometrics = false,
    this.biometricSignInEnabled = false,
    this.status,
    this.error,
  });

  final String? email;
  final bool isConfigured;
  final bool isInitialized;
  final bool isInitializing;
  final bool isLoading;
  final bool canUseBiometrics;
  final bool biometricSignInEnabled;
  final String? status;
  final String? error;

  bool get isSignedIn => email != null;

  CloudAccountState copyWith({
    String? email,
    bool? isConfigured,
    bool? isInitialized,
    bool? isInitializing,
    bool? isLoading,
    bool? canUseBiometrics,
    bool? biometricSignInEnabled,
    String? status,
    String? error,
    bool clearEmail = false,
    bool clearStatus = false,
    bool clearError = false,
  }) => CloudAccountState(
    email: clearEmail ? null : email ?? this.email,
    isConfigured: isConfigured ?? this.isConfigured,
    isInitialized: isInitialized ?? this.isInitialized,
    isInitializing: isInitializing ?? this.isInitializing,
    isLoading: isLoading ?? this.isLoading,
    canUseBiometrics: canUseBiometrics ?? this.canUseBiometrics,
    biometricSignInEnabled:
        biometricSignInEnabled ?? this.biometricSignInEnabled,
    status: clearStatus ? null : status ?? this.status,
    error: clearError ? null : error ?? this.error,
  );
}

class CloudAccountCubit extends Cubit<CloudAccountState> {
  CloudAccountCubit(this._gateway, {this.authenticator, this.biometricSettings})
    : super(
        CloudAccountState(
          isConfigured: _gateway.isConfigured,
          email: _gateway.currentEmail,
        ),
      );

  final CloudAccountGateway _gateway;
  final DeviceAuthenticator? authenticator;
  final BiometricSignInSettingsRepository? biometricSettings;
  StreamSubscription<String?>? _authSubscription;

  Future<void> initialize() async {
    if (state.isInitialized || state.isInitializing) return;
    emit(state.copyWith(isInitializing: true, clearError: true));
    if (_gateway.isConfigured && _authSubscription == null) {
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
    }
    try {
      final enabled = await biometricSettings?.load() ?? false;
      if (!_gateway.isConfigured) {
        emit(
          state.copyWith(
            isInitialized: true,
            isInitializing: false,
            biometricSignInEnabled: enabled,
          ),
        );
        return;
      }
      final rememberedSession = await _gateway.hasRememberedSession;
      final biometricAvailable = await _hasEnrolledBiometrics();
      final canUseBiometrics = rememberedSession && biometricAvailable;
      if (rememberedSession &&
          biometricSettings != null &&
          (!enabled || !canUseBiometrics)) {
        await _gateway.restoreRememberedSession();
      }
      if (isClosed) return;
      emit(
        state.copyWith(
          isInitialized: true,
          isInitializing: false,
          email: _gateway.currentEmail,
          clearEmail: _gateway.currentEmail == null,
          canUseBiometrics: canUseBiometrics,
          biometricSignInEnabled: enabled,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isInitialized: true,
          isInitializing: false,
          error: _messageFor(
            error,
            'Sesi tersimpan tidak dapat dipulihkan. Masuk kembali dengan email.',
          ),
        ),
      );
    }
  }

  Future<bool> _hasEnrolledBiometrics() async {
    final authenticator = this.authenticator;
    if (authenticator == null) return false;
    return authenticator.hasEnrolledBiometrics;
  }

  Future<void> _refreshBiometricAvailability() async {
    try {
      final hasRememberedSession = await _gateway.hasRememberedSession;
      final canUseBiometrics =
          hasRememberedSession && await _hasEnrolledBiometrics();
      if (!isClosed) {
        emit(state.copyWith(canUseBiometrics: canUseBiometrics));
      }
    } catch (_) {
      if (!isClosed) emit(state.copyWith(canUseBiometrics: false));
    }
  }

  Future<void> setBiometricSignInEnabled(bool enabled) async {
    if (state.isLoading) return;
    if (enabled) {
      if (!state.isSignedIn) {
        emit(
          state.copyWith(
            error: 'Masuk terlebih dahulu untuk menyalakan masuk dengan sidik jari atau wajah.',
            clearStatus: true,
          ),
        );
        return;
      }
      final authenticator = this.authenticator;
      if (authenticator == null || !await _hasEnrolledBiometrics()) {
        emit(
          state.copyWith(
            error: 'Siapkan sidik jari atau wajah di pengaturan ponsel terlebih dahulu.',
            clearStatus: true,
          ),
        );
        return;
      }
      if (!await _gateway.hasRememberedSession) {
        emit(
          state.copyWith(
            error: 'Akun ini belum tersimpan di ponsel. Masuk kembali untuk melanjutkan.',
            clearStatus: true,
          ),
        );
        return;
      }
    }
    final settings = biometricSettings;
    if (settings == null) {
      emit(
        state.copyWith(
          error: 'Pengaturan masuk dengan sidik jari atau wajah tidak dapat disimpan.',
          clearStatus: true,
        ),
      );
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true, clearStatus: true));
    try {
      await settings.save(enabled);
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          biometricSignInEnabled: enabled,
          canUseBiometrics: enabled || state.canUseBiometrics,
          status: enabled
              ? 'Sidik jari atau wajah akan diminta saat aplikasi dibuka lagi.'
              : 'Masuk dengan sidik jari atau wajah dimatikan. Akun tetap tersimpan.',
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          error: _messageFor(error, 'Pengaturan masuk tidak dapat disimpan.'),
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
          error: 'Fitur akun online belum tersedia.',
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
      await _refreshBiometricAvailability();
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
          error: 'Fitur akun online belum tersedia.',
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
      await _refreshBiometricAvailability();
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          error: _messageFor(
            error,
            'Tidak dapat masuk. Periksa email, kata sandi, dan koneksi internet.',
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
          error: 'Masuk dengan sidik jari atau wajah belum tersedia. Masuk dengan email terlebih dahulu.',
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
            error: 'Masuk dengan sidik jari atau wajah dibatalkan atau tidak berhasil.',
          ),
        );
        return;
      }
      await _gateway.restoreRememberedSession();
      emit(
        state.copyWith(
          email: _gateway.currentEmail,
          isLoading: false,
          status: 'Berhasil masuk dengan sidik jari atau wajah.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          error: _messageFor(
            error,
            'Masuk dengan sidik jari atau wajah gagal. Coba masuk dengan email dan kata sandi.',
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
          status: 'Berhasil keluar dari akun online. Perjalanan di ponsel tetap tersimpan.',
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
    if (password.length < 8) {
      return 'Kata sandi harus terdiri dari minimal 8 karakter.';
    }
    if (password.length > 128) {
      return 'Kata sandi maksimal 128 karakter.';
    }
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
