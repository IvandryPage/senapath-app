import '../domain/leaderboard_models.dart';

abstract interface class LeaderboardGateway {
  bool get isConfigured;
  bool get isSignedIn;

  Future<LeaderboardSettings> loadSettings();
  Future<List<LeaderboardEntry>> loadEntries(LeaderboardCategory category);
  Future<void> saveConsent({required bool isOptedIn});
  Future<void> recordPersonalBest({
    required int durationSeconds,
    required double distanceMeters,
  });
}
