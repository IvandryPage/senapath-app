import '../../gamification/domain/rider_progress.dart';

enum LeaderboardCategory { duration, distance }

class LeaderboardSettings {
  /// Membuat pengaturan leaderboard berisi status ikut dan nama tampilan.
  const LeaderboardSettings({
    required this.isOptedIn,
    required this.displayName,
  });

  final bool isOptedIn;
  final String? displayName;
}

class LeaderboardEntry {
  /// Membuat entri peringkat dengan skor serta data level dan gaya rider.
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
