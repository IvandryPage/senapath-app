import 'custom_auth_session_manager.dart';
import 'cloud_account_gateway.dart';

class SupabaseCloudAccountGateway implements CloudAccountGateway {
  /// Membuat gateway akun cloud berbasis sesi Supabase.
  const SupabaseCloudAccountGateway({required this._sessionManager});

  final CustomAuthSessionManager _sessionManager;

  /// Menentukan apakah sesi Supabase terkonfigurasi.
  @override
  bool get isConfigured => _sessionManager.isConfigured;

  /// Mengembalikan email pengguna yang sedang masuk.
  @override
  String? get currentEmail => _sessionManager.currentEmail;

  /// Meneruskan aliran perubahan status autentikasi.
  @override
  Stream<String?> get authChanges => _sessionManager.authChanges;

  /// Menentukan apakah ada sesi tersimpan di perangkat.
  @override
  Future<bool> get hasRememberedSession => _sessionManager.hasStoredSession;

  /// Mendaftarkan akun baru lalu menyimpan sesinya.
  @override
  Future<CloudAccountRegistrationResult> register({
    required String email,
    required String password,
  }) async {
    await _sessionManager.authenticate(
      'register',
      values: {'email': email, 'password': password},
    );
    return const CloudAccountRegistrationResult(hasSession: true);
  }

  /// Masuk dengan email dan kata sandi.
  @override
  Future<void> signIn({required String email, required String password}) async {
    await _sessionManager.authenticate(
      'sign-in',
      values: {'email': email, 'password': password},
    );
  }

  /// Memulihkan sesi akun yang tersimpan.
  @override
  Future<void> restoreRememberedSession() =>
      _sessionManager.restoreRememberedSession();

  /// Mengakhiri sesi akun online.
  @override
  Future<void> signOut() => _sessionManager.signOut();
}
