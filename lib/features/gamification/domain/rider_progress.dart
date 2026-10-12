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
