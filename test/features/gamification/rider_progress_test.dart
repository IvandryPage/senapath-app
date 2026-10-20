import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/gamification/domain/rider_progress.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

RideSessionSnapshot _session({
  required String id,
  required DateTime startedAt,
  Duration duration = Duration.zero,
  double distanceMeters = 0,
}) => RideSessionSnapshot(
  id: id,
  startedAt: startedAt,
  endedAt: startedAt.add(duration),
  status: RideSessionStatus.completed,
  totalPausedMilliseconds: 0,
  distanceMeters: distanceMeters,
  currentSpeedMetersPerSecond: 0,
);

void main() {
  group('RiderStyle', () {
    test('parses names defensively', () {
      expect(RiderStyle.fromName(null), RiderStyle.explorer);
      expect(RiderStyle.fromName('CLIMBER'), RiderStyle.climber);
      expect(RiderStyle.fromName('  sprinter '), RiderStyle.sprinter);
      expect(RiderStyle.fromName('unknown'), RiderStyle.explorer);
    });

    test('every style has a label and description', () {
      for (final style in RiderStyle.values) {
        expect(style.label, isNotEmpty);
        expect(style.description, isNotEmpty);
      }
    });
  });

  group('RiderAppearance', () {
    test('round-trips through JSON', () {
      const appearance = RiderAppearance(
        kitColor: RiderKitColor.violet,
        accessory: RiderAccessory.glasses,
      );
      final restored = RiderAppearance.fromJson(appearance.toJson());
      expect(restored, appearance);
    });

    test('rejects unknown values', () {
      expect(
        () => RiderAppearance.fromJson({'kitColor': 'pink', 'accessory': 'helmet'}),
        throwsFormatException,
      );
      expect(
        () => RiderAppearance.fromJson({'kitColor': 'coral', 'accessory': 'cape'}),
        throwsFormatException,
      );
    });

    test('copyWith keeps previous values', () {
      const appearance = RiderAppearance();
      expect(appearance.copyWith(), appearance);
      expect(
        appearance.copyWith(kitColor: RiderKitColor.green),
        const RiderAppearance(
          kitColor: RiderKitColor.green,
          accessory: RiderAccessory.helmet,
        ),
      );
    });
  });

  group('RiderProgress.fromSessions', () {
    test('folds experience, distance and duration from sessions', () {
      final monday = DateTime(2026, 1, 5, 8);
      final progress = RiderProgress.fromSessions(
        [
          _session(
            id: 'a',
            startedAt: monday,
            duration: const Duration(hours: 1),
            distanceMeters: 5000,
          ),
          _session(
            id: 'b',
            startedAt: monday.add(const Duration(days: 1)),
            duration: const Duration(minutes: 30),
            distanceMeters: 2500,
          ),
        ],
        style: RiderStyle.climber,
      );

      // round(5000/1000*15) + (60~/5)*2 + 10 = 109
      // round(2500/1000*15) + (30~/5)*2 + 10 = 60
      expect(progress.experience, 169);
      expect(progress.level, 1);
      expect(progress.completedRides, 2);
      expect(progress.distanceMeters, 7500);
      expect(progress.longestRideMeters, 5000);
      expect(progress.rideDurationSeconds, 5400);
      expect(progress.weekendRides, 0);
      expect(progress.style, RiderStyle.climber);
    });

    test('counts weekend rides using the local start day', () {
      final saturday = DateTime(2026, 1, 3, 6);
      final progress = RiderProgress.fromSessions(
        [_session(id: 'a', startedAt: saturday)],
        style: RiderStyle.explorer,
      );
      expect(progress.weekendRides, 1);
    });

    test('adds bonus experience and recomputes the level', () {
      final progress = RiderProgress.fromSessions(
        const [],
        style: RiderStyle.explorer,
        bonusExperience: 1000,
      );
      expect(progress.experience, 1000);
      expect(progress.level, 3);
      expect(progress.bonusExperience, 1000);
      expect(progress.levelProgress, closeTo(0, 0.0001));
      expect(progress.experienceToNextLevel, 500);
    });

    test('reports level progress within the level', () {
      final progress = RiderProgress.fromSessions(
        const [],
        style: RiderStyle.explorer,
        bonusExperience: 750,
      );
      expect(progress.level, 2);
      expect(progress.levelProgress, closeTo(0.5, 0.0001));
      expect(progress.experienceToNextLevel, 250);
    });
  });

  group('RiderRank', () {
    test('maps levels to ranks', () {
      expect(RiderRank.forLevel(1), RiderRank.rookie);
      expect(RiderRank.forLevel(10), RiderRank.rookie);
      expect(RiderRank.forLevel(11), RiderRank.clubRider);
      expect(RiderRank.forLevel(31), RiderRank.granFondo);
      expect(RiderRank.forLevel(61), RiderRank.eliteRider);
      expect(RiderRank.forLevel(101), RiderRank.proRider);
      expect(RiderRank.forLevel(9999), RiderRank.proRider);
    });

    test('formats level ranges', () {
      expect(RiderRank.rookie.levelRange, 'Level 1–10');
      expect(RiderRank.proRider.levelRange, 'Level 101+');
    });
  });

  group('RiderAchievement', () {
    test('tracks unlock state and progress fraction', () {
      final progress = RiderProgress.fromSessions(
        [
          _session(
            id: 'a',
            startedAt: DateTime(2026, 1, 5),
            distanceMeters: 12000,
          ),
        ],
        style: RiderStyle.explorer,
      );

      final achievements = progress.achievements;
      expect(achievements.length, 31);

      final firstRide = achievements.firstWhere((item) => item.target == 1);
      expect(firstRide.isUnlocked, isTrue);
      expect(firstRide.progressFraction, 1);

      final distanceAchievement = achievements.firstWhere(
        (item) => item.icon == RiderAchievementIcon.distance && item.target == 25,
      );
      expect(distanceAchievement.progress, 12);
      expect(distanceAchievement.isUnlocked, isFalse);
      expect(distanceAchievement.progressFraction, closeTo(12 / 25, 0.0001));

      final weekendAchievement = achievements.firstWhere(
        (item) => item.icon == RiderAchievementIcon.weekend,
      );
      expect(weekendAchievement.isUnlocked, isFalse);
      expect(weekendAchievement.progressFraction, 0);
    });
  });
}
