import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/features/account_sync/data/account_cloud_gateway.dart';
import 'package:senapath/features/gamification/data/rider_profile_repository.dart';
import 'package:senapath/features/gamification/domain/rider_progress.dart';
import 'package:senapath/features/gamification/presentation/rider_gamification_cubit.dart';
import 'package:senapath/features/logistics/data/logistics_repository.dart';
import 'package:senapath/features/logistics/domain/logistics_models.dart';
import 'package:senapath/features/profile/data/user_profile_repository.dart';
import 'package:senapath/features/profile/domain/user_profile.dart';
import 'package:senapath/features/profile/presentation/profile_cubit.dart';
import 'package:senapath/features/progress/data/activity_goals_repository.dart';
import 'package:senapath/features/progress/domain/activity_progress.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

void main() {
  group('ActivityGoalsRepository cloud sync', () {
    test('uses the cloud copy as the source of truth and caches it', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final gateway = _FakeAccountCloudGateway();
      final cloudGoals = [
        const ActivityGoal(
          id: 'cloud-distance',
          metric: GoalMetric.distanceMeters,
          target: 42000,
          period: ProgressPeriod.week,
        ),
      ];
      gateway.settings['activity_goals_v1'] = cloudGoals
          .map((goal) => goal.toJson())
          .toList();
      final repository = ActivityGoalsRepository(database, cloud: gateway);

      final loaded = await repository.load();

      expect(loaded.map((goal) => goal.id), ['cloud-distance']);
      final cached = await ActivityGoalsRepository(database).load();
      expect(cached.map((goal) => goal.id), ['cloud-distance']);
    });

    test('seeds the cloud with local goals when it is empty', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final localGoals = [
        const ActivityGoal(
          id: 'local-distance',
          metric: GoalMetric.distanceMeters,
          target: 15000,
          period: ProgressPeriod.month,
        ),
      ];
      await ActivityGoalsRepository(database).save(localGoals);
      final gateway = _FakeAccountCloudGateway();

      final loaded = await ActivityGoalsRepository(
        database,
        cloud: gateway,
      ).load();

      expect(loaded.map((goal) => goal.id), ['local-distance']);
      expect(gateway.settings['activity_goals_v1'], isNotNull);
    });
  });

  group('LogisticsRepository cloud sync', () {
    test('loads the account budget from the cloud', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final gateway = _FakeAccountCloudGateway();
      gateway.settings['logistics_data_v1'] = const LogisticsData(
        rateSource: 'Cloud',
      ).toJson();

      final loaded = await LogisticsRepository(database, cloud: gateway).load();

      expect(loaded.rateSource, 'Cloud');
    });
  });

  group('RiderGamificationCubit cloud merge', () {
    test('merges the greater cloud progress and restores appearance', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final gateway = _FakeAccountCloudGateway()
        ..progress = const CloudRiderProgress(
          style: RiderStyle.ace,
          level: 3,
          experience: 1200,
          distanceMeters: 50000,
          completedRides: 10,
          rideDurationSeconds: 40000,
          weekendRides: 4,
          appearance: RiderAppearance(kitColor: RiderKitColor.blue),
        );
      final cubit = RiderGamificationCubit(
        RiderProfileRepository(database, cloudGateway: gateway),
      );
      addTearDown(cubit.close);

      await cubit.load([_session('ride-1', DateTime(2026, 6, 16, 8), 1000)]);

      final progress = cubit.state.progress!;
      expect(progress.experience, 1200);
      expect(progress.level, 3);
      expect(progress.distanceMeters, 50000);
      expect(progress.completedRides, 10);
      expect(progress.rideDurationSeconds, 40000);
      expect(progress.weekendRides, 4);
      expect(progress.style, RiderStyle.ace);
      expect(cubit.state.appearance.kitColor, RiderKitColor.blue);
      expect(gateway.pushRiderProgressCalls, greaterThanOrEqualTo(1));
    });

    test(
      'pushes local progress to the cloud when the account is empty',
      () async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final gateway = _FakeAccountCloudGateway();
        final cubit = RiderGamificationCubit(
          RiderProfileRepository(database, cloudGateway: gateway),
        );
        addTearDown(cubit.close);

        await cubit.load([_session('ride-1', DateTime(2026, 6, 16, 8), 2000)]);

        expect(gateway.pushedProgress, isNotNull);
        expect(gateway.pushedProgress!.completedRides, 1);
        expect(gateway.pushedProgress!.distanceMeters, 2000);
      },
    );
  });

  group('ProfileCubit emergency contacts cloud sync', () {
    test('adopts cloud contacts as the account source of truth', () async {
      final repository = _FakeProfileRepository(
        contacts: [
          const EmergencyContact(
            id: 'local',
            name: 'Local',
            phone: '1',
            relationship: 'friend',
          ),
        ],
        cloudContacts: [
          const EmergencyContact(
            id: 'cloud',
            name: 'Cloud',
            phone: '2',
            relationship: 'sister',
          ),
        ],
      );
      final cubit = ProfileCubit(repository);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.contacts.map((contact) => contact.id), ['cloud']);
      expect(repository.contacts.map((contact) => contact.id), ['cloud']);
    });

    test('uploads local contacts when the account has none yet', () async {
      final repository = _FakeProfileRepository(
        contacts: [
          const EmergencyContact(
            id: 'local',
            name: 'Local',
            phone: '1',
            relationship: 'friend',
          ),
        ],
      );
      final cubit = ProfileCubit(repository);
      addTearDown(cubit.close);

      await cubit.load();

      expect(repository.savedCloudContacts, isTrue);
      expect(repository.cloudContacts?.map((contact) => contact.id), ['local']);
    });
  });
}

RideSessionSnapshot _session(String id, DateTime startedAt, double distance) =>
    RideSessionSnapshot(
      id: id,
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(minutes: 10)),
      status: RideSessionStatus.completed,
      totalPausedMilliseconds: 0,
      distanceMeters: distance,
      currentSpeedMetersPerSecond: 0,
    );

class _FakeAccountCloudGateway implements AccountCloudGateway {
  @override
  final bool isConfigured = true;

  @override
  bool isSignedIn = true;

  final Map<String, Object?> settings = {};
  CloudRiderProgress? progress;
  CloudRiderProgress? pushedProgress;
  int pushRiderProgressCalls = 0;

  @override
  Future<Object?> pullSetting(String key) async => settings[key];

  @override
  Future<void> pushSetting(String key, Object? value) async {
    settings[key] = value;
  }

  @override
  Future<void> pushRideSession(
    RideSessionSnapshot session,
    List<TelemetryLocation> points,
  ) async {}

  @override
  Future<List<CloudRideSession>> pullRideSessions() async => const [];

  @override
  Future<void> deleteRideSession(String sessionId) async {}

  @override
  Future<void> pushRiderProgress({
    required RiderStyle style,
    required int level,
    required int experience,
    required double distanceMeters,
    required int completedRides,
    required int rideDurationSeconds,
    required int weekendRides,
    required RiderAppearance appearance,
  }) async {
    pushRiderProgressCalls++;
    pushedProgress = CloudRiderProgress(
      style: style,
      level: level,
      experience: experience,
      distanceMeters: distanceMeters,
      completedRides: completedRides,
      rideDurationSeconds: rideDurationSeconds,
      weekendRides: weekendRides,
      appearance: appearance,
    );
  }

  @override
  Future<CloudRiderProgress?> pullRiderProgress() async => progress;
}

class _FakeProfileRepository
    implements
        UserProfileRepository,
        CloudUserProfileRepository,
        CloudContactsRepository {
  _FakeProfileRepository({this.contacts = const [], this.cloudContacts});

  UserProfile profile = const UserProfile(displayName: 'Rider');
  List<EmergencyContact> contacts;
  List<EmergencyContact>? cloudContacts;
  UserProfile? cloudProfile;
  bool savedCloudContacts = false;

  @override
  bool get isCloudSignedIn => true;

  @override
  Future<UserProfile> loadProfile() async => profile;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    this.profile = profile;
  }

  @override
  Future<List<EmergencyContact>> loadContacts() async => contacts;

  @override
  Future<void> saveContacts(List<EmergencyContact> contacts) async {
    this.contacts = contacts;
  }

  @override
  Future<Uint8List?> loadAvatar() async => null;

  @override
  Future<void> saveAvatar(Uint8List imageBytes) async {}

  @override
  Future<UserProfile?> loadCloudProfile() async => cloudProfile;

  @override
  Future<void> saveCloudProfile(UserProfile profile) async {
    cloudProfile = profile;
  }

  @override
  Future<List<EmergencyContact>?> loadCloudContacts() async => cloudContacts;

  @override
  Future<void> saveCloudContacts(List<EmergencyContact> contacts) async {
    cloudContacts = contacts;
    savedCloudContacts = true;
  }
}
