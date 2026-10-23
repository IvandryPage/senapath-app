import '../domain/ride_session.dart';

/// Antarmuka gateway untuk sinkronisasi ringkasan sesi.
abstract interface class SessionSyncGateway {
  /// Menentukan apakah gateway dikonfigurasi.
  bool get isConfigured;
  /// Menentukan apakah pengguna masuk.
  bool get isSignedIn;

  /// Mengunggah ringkasan sesi ke layanan sinkronisasi.
  Future<void> uploadSummary(
    RideSessionSummary summary, {
    String? shareWithTeamId,
  });
}
