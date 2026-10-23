import '../../gamification/domain/rider_progress.dart';
import '../../session/domain/ride_session.dart';

/// A complete ride session (metadata plus GPS/telemetry track) as stored in the
/// account cloud database.
class CloudRideSession {
  /// Membuat sesi perjalanan cloud beserta titik telemetri.
  const CloudRideSession({required this.session, required this.points});

  final RideSessionSnapshot session;
  final List<TelemetryLocation> points;
}

/// Account gamification progress persisted alongside the rider profile.
class CloudRiderProgress {
  /// Membuat data progres pengendara cloud.
  const CloudRiderProgress({
    required this.style,
    required this.level,
    required this.experience,
    required this.distanceMeters,
    required this.completedRides,
    required this.rideDurationSeconds,
    required this.weekendRides,
    this.appearance,
  });

  final RiderStyle style;
  final int level;
  final int experience;
  final double distanceMeters;
  final int completedRides;
  final int rideDurationSeconds;
  final int weekendRides;
  final RiderAppearance? appearance;
}

/// Account-scoped cloud storage gateway. Every signed-in device reads and
/// writes through this so the cloud stays the single source of truth.
abstract interface class AccountCloudGateway {
  /// Menentukan apakah penyimpanan cloud terkonfigurasi.
  bool get isConfigured;

  /// Menentukan apakah pengguna telah masuk.
  bool get isSignedIn;

  /// Reads a JSON settings document for the current account, or null.
  Future<Object?> pullSetting(String key);

  /// Writes a JSON settings document for the current account.
  Future<void> pushSetting(String key, Object? value);

  /// Menyimpan sesi perjalanan dan telemetrinya ke cloud.
  Future<void> pushRideSession(
    RideSessionSnapshot session,
    List<TelemetryLocation> points,
  );

  /// Mengambil semua sesi perjalanan dari cloud.
  Future<List<CloudRideSession>> pullRideSessions();

  /// Menghapus sesi perjalanan dan telemetrinya dari cloud.
  Future<void> deleteRideSession(String sessionId);

  /// Menyimpan progres pengendara ke cloud.
  Future<void> pushRiderProgress({
    required RiderStyle style,
    required int level,
    required int experience,
    required double distanceMeters,
    required int completedRides,
    required int rideDurationSeconds,
    required int weekendRides,
    required RiderAppearance appearance,
  });

  /// Mengambil progres pengendara dari cloud, atau null.
  Future<CloudRiderProgress?> pullRiderProgress();
}
