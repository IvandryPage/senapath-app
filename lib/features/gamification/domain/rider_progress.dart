import '../../session/domain/ride_session.dart';

enum RiderStyle {
  sprinter,
  climber,
  explorer,
  ace;

  static RiderStyle fromName(Object? name) => RiderStyle.values.firstWhere(
    (style) => style.name == name,
    orElse: () => RiderStyle.explorer,
  );

  String get label => switch (this) {
    RiderStyle.sprinter => 'Sprinter',
    RiderStyle.climber => 'Climber',
    RiderStyle.explorer => 'Explorer',
    RiderStyle.ace => 'Ace / All-rounder',
  };

  String get description => switch (this) {
    RiderStyle.sprinter => 'Fokus pada kecepatan dan konsistensi.',
    RiderStyle.climber => 'Tangguh menghadapi tanjakan.',
    RiderStyle.explorer => 'Senang mencoba rute baru.',
    RiderStyle.ace => 'Serba bisa untuk berbagai medan dan strategi lomba.',
  };
}

enum RiderKitColor {
  coral(0xFFE66A52, 'Koral'),
  blue(0xFF3976B8, 'Biru'),
  green(0xFF3B8C6E, 'Hijau'),
  violet(0xFF7955A6, 'Ungu');

  const RiderKitColor(this.value, this.label);

  final int value;
  final String label;
}

enum RiderAccessory {
  helmet('Helm', 'sports_motorsports'),
  glasses('Kacamata', 'visibility'),
  none('Tanpa aksesori', 'none');

  const RiderAccessory(this.label, this.serializedName);

  final String label;
  final String serializedName;
}

class RiderAppearance {
  const RiderAppearance({
    this.kitColor = RiderKitColor.coral,
    this.accessory = RiderAccessory.helmet,
  });

  final RiderKitColor kitColor;
  final RiderAccessory accessory;

  RiderAppearance copyWith({
    RiderKitColor? kitColor,
    RiderAccessory? accessory,
  }) => RiderAppearance(
    kitColor: kitColor ?? this.kitColor,
    accessory: accessory ?? this.accessory,
  );

  @override
  bool operator ==(Object other) =>
      other is RiderAppearance &&
      other.kitColor == kitColor &&
      other.accessory == accessory;

  @override
  int get hashCode => Object.hash(kitColor, accessory);

  Map<String, Object?> toJson() => {
    'kitColor': kitColor.name,
    'accessory': accessory.name,
  };

  factory RiderAppearance.fromJson(Map<String, dynamic> json) {
    final kitColorName = json['kitColor'];
    final accessoryName = json['accessory'];
    return RiderAppearance(
      kitColor: RiderKitColor.values.firstWhere(
        (value) => value.name == kitColorName,
        orElse: () => throw const FormatException(
          'Warna karakter rider tersimpan tidak valid.',
        ),
      ),
      accessory: RiderAccessory.values.firstWhere(
        (value) => value.name == accessoryName,
        orElse: () => throw const FormatException(
          'Aksesori karakter rider tersimpan tidak valid.',
        ),
      ),
    );
  }
}

class RiderProgress {
  const RiderProgress({
    required this.experience,
    required this.level,
    required this.distanceMeters,
    required this.completedRides,
    required this.style,
    this.rideDurationSeconds = 0,
    this.longestRideMeters = 0,
    this.weekendRides = 0,
  });

  static const experiencePerLevel = 500;

  final int experience;
  final int level;
  final double distanceMeters;
  final int completedRides;
  final RiderStyle style;
  final int rideDurationSeconds;
  final double longestRideMeters;
  final int weekendRides;

  double get levelProgress =>
      (experience % experiencePerLevel) / experiencePerLevel;

  int get experienceToNextLevel =>
      experiencePerLevel - (experience % experiencePerLevel);

  RiderRank get rank => RiderRank.forLevel(level);

  List<RiderAchievement> get achievements => [
    for (final target in const [1, 5, 10, 25, 50, 100])
      RiderAchievement(
        title: switch (target) {
          1 => 'Gowes Pertama',
          5 => 'Mulai Konsisten',
          10 => 'Rutin Gowes',
          25 => 'Peloton Kecil',
          50 => 'Pecinta Gowes',
          _ => 'Century of Rides',
        },
        description: 'Selesaikan $target sesi bersepeda.',
        icon: RiderAchievementIcon.consistency,
        progress: completedRides,
        target: target,
        unit: 'sesi',
      ),
    for (final target in const [10, 25, 50, 100, 250, 500, 1000])
      RiderAchievement(
        title: switch (target) {
          10 => 'Pemula Jarak',
          25 => 'Quarter Century',
          50 => 'Half Century',
          100 => 'Centurion',
          250 => 'Randonneur',
          500 => 'Penjelajah Jarak Jauh',
          _ => 'Seribu Kilometer',
        },
        description: 'Tempuh total jarak $target km.',
        icon: RiderAchievementIcon.distance,
        progress: (distanceMeters / 1000).floor(),
        target: target,
        unit: 'km',
      ),
    for (final target in const [5, 10, 11, 20, 31, 50, 61, 101])
      RiderAchievement(
        title: 'Level $target · ${RiderRank.forLevel(target).title}',
        description:
            'Capai level $target dan raih title ${RiderRank.forLevel(target).title}.',
        icon: RiderAchievementIcon.rank,
        progress: level,
        target: target,
      ),
    for (final target in const [5, 10, 25, 50, 100])
      RiderAchievement(
        title: switch (target) {
          5 => 'Waktu di Sadel',
          10 => 'Setengah Hari Gowes',
          25 => 'Pengayuh Tangguh',
          50 => 'Endurance Rider',
          _ => 'Ribuan Menit di Sadel',
        },
        description: 'Kumpulkan $target jam waktu gowes.',
        icon: RiderAchievementIcon.duration,
        progress: rideDurationSeconds ~/ 3600,
        target: target,
        unit: 'jam',
      ),
    for (final target in const [25, 50, 100])
      RiderAchievement(
        title: switch (target) {
          25 => 'Long Ride',
          50 => 'Metric Half Century',
          _ => 'Metric Century',
        },
        description: 'Selesaikan satu sesi sejauh $target km atau lebih.',
        icon: RiderAchievementIcon.longRide,
        progress: (longestRideMeters / 1000).floor(),
        target: target,
        unit: 'km',
      ),
    for (final target in const [5, 20])
      RiderAchievement(
        title: target == 5 ? 'Weekend Warrior' : 'Raja Akhir Pekan',
        description: 'Selesaikan $target sesi pada hari Sabtu atau Minggu.',
        icon: RiderAchievementIcon.weekend,
        progress: weekendRides,
        target: target,
        unit: 'sesi',
      ),
  ];

  factory RiderProgress.fromSessions(
    List<RideSessionSnapshot> sessions, {
    required RiderStyle style,
  }) {
    var experience = 0;
    var distanceMeters = 0.0;
    var rideDurationSeconds = 0;
    var longestRideMeters = 0.0;
    var weekendRides = 0;
    for (final session in sessions) {
      distanceMeters += session.distanceMeters;
      final duration = session.durationAt(
        session.endedAt ?? session.startedAt,
      );
      final activeMinutes = duration.inMinutes;
      rideDurationSeconds += duration.inSeconds;
      if (session.distanceMeters > longestRideMeters) {
        longestRideMeters = session.distanceMeters;
      }
      final weekday = session.startedAt.toLocal().weekday;
      if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
        weekendRides++;
      }
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
      rideDurationSeconds: rideDurationSeconds,
      longestRideMeters: longestRideMeters,
      weekendRides: weekendRides,
    );
  }
}

enum RiderRank {
  rookie(minLevel: 1, maxLevel: 10, title: 'Rookie'),
  clubRider(minLevel: 11, maxLevel: 30, title: 'Club Rider'),
  granFondo(minLevel: 31, maxLevel: 60, title: 'Gran Fondo'),
  eliteRider(minLevel: 61, maxLevel: 100, title: 'Elite Rider'),
  proRider(minLevel: 101, maxLevel: null, title: 'Pro Rider');

  const RiderRank({
    required this.minLevel,
    required this.maxLevel,
    required this.title,
  });

  final int minLevel;
  final int? maxLevel;
  final String title;

  static RiderRank forLevel(int level) => RiderRank.values.firstWhere(
    (rank) =>
        level >= rank.minLevel &&
        (rank.maxLevel == null || level <= rank.maxLevel!),
  );

  String get levelRange =>
      maxLevel == null ? 'Level $minLevel+' : 'Level $minLevel–$maxLevel';
}

class RiderAchievement {
  const RiderAchievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.progress,
    required this.target,
    this.unit = '',
  });

  final String title;
  final String description;
  final RiderAchievementIcon icon;
  final int progress;
  final int target;
  final String unit;

  bool get isUnlocked => progress >= target;

  double get progressFraction => (progress / target).clamp(0, 1).toDouble();
}

enum RiderAchievementIcon {
  consistency,
  distance,
  rank,
  duration,
  longRide,
  weekend,
}
