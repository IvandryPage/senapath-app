import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/cloud_account_gateway.dart';

class CloudAccountState {
  const CloudAccountState({
    this.email,
    this.isConfigured = false,
    this.isLoading = false,
    this.status,
    this.error,
  });

  final String? email;
  final bool isConfigured;
  final bool isLoading;
  final String? status;
  final String? error;

  bool get isSignedIn => email != null;

  CloudAccountState copyWith({
    String? email,
    bool? isConfigured,
    bool? isLoading,
    String? status,
    String? error,
    bool clearEmail = false,
    bool clearStatus = false,
    bool clearError = false,
  }) => CloudAccountState(
    email: clearEmail ? null : email ?? this.email,
    isConfigured: isConfigured ?? this.isConfigured,
    isLoading: isLoading ?? this.isLoading,
    status: clearStatus ? null : status ?? this.status,
    error: clearError ? null : error ?? this.error,
  );
}

class CloudAccountCubit extends Cubit<CloudAccountState> {
  CloudAccountCubit(this._gateway)
    : super(
        CloudAccountState(
          isConfigured: _gateway.isConfigured,
          email: _gateway.currentEmail,
        ),
      );

  final CloudAccountGateway _gateway;
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
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
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
          email: result.hasSession ? normalizedEmail : null,
          clearEmail: !result.hasSession,
          isLoading: false,
          status: result.hasSession
              ? 'Akun dibuat dan berhasil masuk.'
              : 'Akun dibuat. Periksa email untuk verifikasi sebelum masuk.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Pendaftaran gagal. Periksa email, koneksi, dan pengaturan Auth Supabase.',
        ),
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
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
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Tidak dapat masuk. Periksa email, password, dan verifikasi email.',
        ),
      );
    }
  }

  Future<void> sendPasswordReset(String email) async {
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
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Tautan pemulihan tidak dapat dikirim. Periksa koneksi dan Auth Supabase.',
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
          status:
              'Berhasil keluar dari akun online. Data lokal tetap tersimpan.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Keluar dari akun online gagal. Coba lagi saat jaringan tersedia.',
        ),
      );
    }
  }

  String? _validate(String email, String password) {
    if (!_isValidEmail(email)) return 'Masukkan alamat email yang valid.';
    if (password.length < 8) return 'Password harus berisi minimal 8 karakter.';
    return null;
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    return super.close();
  }
}
