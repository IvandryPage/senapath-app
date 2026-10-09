import '../../gamification/domain/rider_progress.dart';

enum LeaderboardCategory { duration, distance }

class LeaderboardSettings {
  const LeaderboardSettings({required this.isOptedIn, required this.alias});

  final bool isOptedIn;
  final String? alias;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.alias,
    required this.score,
    this.riderLevel = 1,
    this.riderStyle = RiderStyle.explorer,
    this.riderExperience = 0,
  });

  final int rank;
  final String alias;
  final double score;
  final int riderLevel;
  final RiderStyle riderStyle;
  final int riderExperience;
}
