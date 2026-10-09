import '../../session/domain/ride_session.dart';

enum RiderStyle {
  sprinter,
  climber,
  explorer;

  String get label => switch (this) {
    RiderStyle.sprinter => 'Sprinter',
    RiderStyle.climber => 'Climber',
    RiderStyle.explorer => 'Explorer',
  };

  String get description => switch (this) {
    RiderStyle.sprinter => 'Fokus pada kecepatan dan konsistensi.',
    RiderStyle.climber => 'Tangguh menghadapi tanjakan.',
    RiderStyle.explorer => 'Senang mencoba rute baru.',
  };
}

class RiderProgress {
  const RiderProgress({
    required this.experience,
    required this.level,
    required this.distanceMeters,
    required this.completedRides,
    required this.style,
  });

  static const experiencePerLevel = 500;

  final int experience;
  final int level;
  final double distanceMeters;
  final int completedRides;
  final RiderStyle style;

  double get levelProgress =>
      (experience % experiencePerLevel) / experiencePerLevel;

  int get experienceToNextLevel =>
      experiencePerLevel - (experience % experiencePerLevel);

  factory RiderProgress.fromSessions(
    List<RideSessionSnapshot> sessions, {
    required RiderStyle style,
  }) {
    var experience = 0;
    var distanceMeters = 0.0;
    for (final session in sessions) {
      distanceMeters += session.distanceMeters;
      final activeMinutes = session
          .durationAt(session.endedAt ?? session.startedAt)
          .inMinutes;
      experience +=
          (session.distanceMeters / 1000 * 15).round() +
          (activeMinutes ~/ 5) * 2;
      if (session.distanceMeters > 0 || activeMinutes > 0) {
        experience += 10;
      }
    }
    return RiderProgress(
      experience: experience,
      level: experience ~/ experiencePerLevel + 1,
      distanceMeters: distanceMeters,
      completedRides: sessions.length,
      style: style,
    );
  }
}
