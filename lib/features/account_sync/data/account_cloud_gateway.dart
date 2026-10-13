import '../../gamification/domain/rider_progress.dart';
import '../../session/domain/ride_session.dart';

/// A complete ride session (metadata plus GPS/telemetry track) as stored in the
/// account cloud database.
class CloudRideSession {
  const CloudRideSession({required this.session, required this.points});

  final RideSessionSnapshot session;
  final List<TelemetryLocation> points;
}

/// Account gamification progress persisted alongside the rider profile.
class CloudRiderProgress {
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
  bool get isConfigured;
  bool get isSignedIn;

  /// Reads a JSON settings document for the current account, or null.
  Future<Object?> pullSetting(String key);

  /// Writes a JSON settings document for the current account.
  Future<void> pushSetting(String key, Object? value);

  Future<void> pushRideSession(
    RideSessionSnapshot session,
    List<TelemetryLocation> points,
  );

  Future<List<CloudRideSession>> pullRideSessions();

  Future<void> deleteRideSession(String sessionId);

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

  Future<CloudRiderProgress?> pullRiderProgress();
}
