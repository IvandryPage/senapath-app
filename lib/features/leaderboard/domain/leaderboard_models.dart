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
  });

  final int rank;
  final String alias;
  final double score;
}
