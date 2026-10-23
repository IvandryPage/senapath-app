abstract interface class RideCoachGateway {
  /// Menandakan layanan pelatih AI sudah dikonfigurasi.
  bool get isConfigured;

  /// Menandakan pengguna sudah masuk ke akun online.
  bool get isSignedIn;

  /// Memeriksa konfigurasi layanan dan mengembalikan pesan diagnostik.
  Future<String> diagnoseConfiguration();

  /// Meminta saran pelatih AI dari [rideContext] dengan [consent] pengguna.
  Future<String> recommend({
    required Map<String, Object?> rideContext,
    required bool consent,
  });

  /// Meminta briefing pra-perjalanan dari data rute dan cuaca.
  Future<String> prepareRide({
    required Map<String, Object?> routeAndWeather,
    required bool consent,
  });
}
