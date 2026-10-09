import '../../gamification/domain/rider_progress.dart';

class CyclingTeam {
  const CyclingTeam({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.role,
    required this.memberCount,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String role;
  final int memberCount;

  bool get isManager => role == 'manager';
}

class CyclingTeamMember {
  const CyclingTeamMember({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    this.riderStyle = RiderStyle.explorer,
    this.riderLevel = 1,
    this.experience = 0,
  });

  final String userId;
  final String displayName;
  final String role;
  final DateTime joinedAt;
  final RiderStyle riderStyle;
  final int riderLevel;
  final int experience;

  bool get isManager => role == 'manager';
}

class TeamRideSummary {
  const TeamRideSummary({
    required this.userId,
    required this.sessionId,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.sampleCount,
    required this.elevationGainMeters,
    required this.elevationSource,
  });

  final String userId;
  final String sessionId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final double distanceMeters;
  final int sampleCount;
  final double? elevationGainMeters;
  final String elevationSource;
}

class CyclingTeamDashboard {
  const CyclingTeamDashboard({
    required this.team,
    required this.members,
    required this.sharedSessions,
  });

  final CyclingTeam team;
  final List<CyclingTeamMember> members;
  final List<TeamRideSummary> sharedSessions;

  double get totalDistanceMeters =>
      sharedSessions.fold(0, (total, ride) => total + ride.distanceMeters);

  int get totalDurationSeconds =>
      sharedSessions.fold(0, (total, ride) => total + ride.durationSeconds);

  double get totalElevationGainMeters => sharedSessions.fold(
    0,
    (total, ride) => total + (ride.elevationGainMeters ?? 0),
  );

  int get totalSampleCount =>
      sharedSessions.fold(0, (total, ride) => total + ride.sampleCount);

  List<TeamRideSummary> sessionsFor(String userId) => sharedSessions
      .where((ride) => ride.userId == userId)
      .toList(growable: false);
}
