import '../../gamification/domain/rider_progress.dart';

class CyclingTeam {
  /// Membuat data tim dengan identitas, kode undangan, peran, dan jumlah anggota.
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

  /// Menandakan pengguna berperan sebagai ketua tim.
  bool get isManager => role == 'manager';
}

class CyclingTeamMember {
  /// Membuat data anggota tim dengan profil rider dan waktu bergabung.
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

  /// Menandakan anggota tim ini berperan sebagai ketua.
  bool get isManager => role == 'manager';
}

class TeamRideSummary {
  /// Membuat ringkasan perjalanan yang dibagikan ke tim.
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
  /// Membuat dashboard tim berisi data tim, anggota, dan perjalanan bersama.
  const CyclingTeamDashboard({
    required this.team,
    required this.members,
    required this.sharedSessions,
  });

  final CyclingTeam team;
  final List<CyclingTeamMember> members;
  final List<TeamRideSummary> sharedSessions;

  /// Menjumlahkan jarak seluruh perjalanan yang dibagikan ke tim.
  double get totalDistanceMeters =>
      sharedSessions.fold(0, (total, ride) => total + ride.distanceMeters);

  /// Menjumlahkan durasi seluruh perjalanan yang dibagikan ke tim.
  int get totalDurationSeconds =>
      sharedSessions.fold(0, (total, ride) => total + ride.durationSeconds);

  /// Menjumlahkan elevasi naik dari seluruh perjalanan yang dibagikan.
  double get totalElevationGainMeters => sharedSessions.fold(
    0,
    (total, ride) => total + (ride.elevationGainMeters ?? 0),
  );

  /// Menjumlahkan jumlah sampel dari seluruh perjalanan yang dibagikan.
  int get totalSampleCount =>
      sharedSessions.fold(0, (total, ride) => total + ride.sampleCount);

  /// Mengambil perjalanan yang dibagikan oleh anggota tertentu.
  List<TeamRideSummary> sessionsFor(String userId) => sharedSessions
      .where((ride) => ride.userId == userId)
      .toList(growable: false);
}
