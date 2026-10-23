class CloudAccountRegistrationResult {
  /// Membuat hasil pendaftaran akun cloud.
  const CloudAccountRegistrationResult({required this.hasSession});

  final bool hasSession;
}

abstract interface class CloudAccountGateway {
  /// Menentukan apakah fitur akun online tersedia.
  bool get isConfigured;

  /// Email pengguna yang sedang masuk, atau null.
  String? get currentEmail;

  /// Aliran perubahan email saat sesi masuk atau keluar.
  Stream<String?> get authChanges;

  /// Menentukan apakah ada sesi akun tersimpan di perangkat.
  Future<bool> get hasRememberedSession;

  /// Mendaftarkan akun baru dengan email dan kata sandi.
  Future<CloudAccountRegistrationResult> register({
    required String email,
    required String password,
  });

  /// Masuk dengan email dan kata sandi.
  Future<void> signIn({required String email, required String password});

  /// Memulihkan sesi akun yang tersimpan di perangkat.
  Future<void> restoreRememberedSession();

  /// Mengakhiri sesi akun online.
  Future<void> signOut();
}
