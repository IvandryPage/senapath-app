import '../domain/leaderboard_models.dart';

abstract interface class LeaderboardGateway {
  /// Menandakan layanan leaderboard sudah dikonfigurasi pada aplikasi.
  bool get isConfigured;
  /// Menandakan pengguna sudah masuk ke akun online.
  bool get isSignedIn;

  /// Memuat pengaturan keikutsertaan dan nama tampilan pengguna.
  Future<LeaderboardSettings> loadSettings();
  /// Memuat daftar peringkat untuk kategori durasi atau jarak.
  Future<List<LeaderboardEntry>> loadEntries(LeaderboardCategory category);
  /// Menyimpan pilihan pengguna untuk ikut atau berhenti dari leaderboard.
  Future<void> saveConsent({required bool isOptedIn});
  /// Mengirim rekor pribadi terbaik untuk durasi dan jarak ke server.
  Future<void> recordPersonalBest({
    required int durationSeconds,
    required double distanceMeters,
  });
}
