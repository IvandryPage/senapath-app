import '../../gamification/domain/rider_progress.dart';

enum LeaderboardCategory { duration, distance }

class LeaderboardSettings {
  const LeaderboardSettings({
    required this.isOptedIn,
    required this.displayName,
  });

  final bool isOptedIn;
  final String? displayName;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.displayName,
    required this.score,
    this.riderLevel = 1,
    this.riderStyle = RiderStyle.explorer,
    this.riderExperience = 0,
  });

  final int rank;
  final String displayName;
  final double score;
  final int riderLevel;
  final RiderStyle riderStyle;
  final int riderExperience;
}
