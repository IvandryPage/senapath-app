import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/leaderboard/data/leaderboard_gateway.dart';
import 'package:senapath/features/leaderboard/domain/leaderboard_models.dart';
import 'package:senapath/features/leaderboard/presentation/leaderboard_cubit.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

void main() {
  late _FakeLeaderboardGateway gateway;
  late LeaderboardCubit cubit;

  setUp(() {
    gateway = _FakeLeaderboardGateway();
    cubit = LeaderboardCubit(gateway);
  });

  tearDown(() async => cubit.close());

  test('loads public results only after opt-in and can opt out', () async {
    await cubit.load();
    expect(cubit.state.settings?.isOptedIn, isFalse);
    expect(gateway.loadEntriesCalls, 0);

    cubit.updateLocalRecords([
      _completedSession('ride-a', 5400, 32000),
      _completedSession('ride-b', 3600, 45000),
    ]);
    await cubit.saveConsent(isOptedIn: true);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.settings?.isOptedIn, isTrue);
    expect(cubit.state.entries, hasLength(1));
    expect(gateway.recordedDuration, 5400);
    expect(gateway.recordedDistance, 45000);

    await cubit.saveConsent(isOptedIn: false);
    expect(cubit.state.settings?.isOptedIn, isFalse);
    expect(cubit.state.entries, isEmpty);
    expect(gateway.loadEntriesCalls, 2);
  });

  test(
    'records completed ride personal bests automatically after opt-in',
    () async {
      await cubit.load();
      await cubit.saveConsent(isOptedIn: true);
      cubit.updateLocalRecords([
        _completedSession('ride-a', 7200, 28000),
        _completedSession('ride-b', 3600, 52000),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(gateway.recordedDuration, 7200);
      expect(gateway.recordedDistance, 52000);
      expect(cubit.state.error, isNull);
    },
  );

  test('stores profile records without publishing before opt-in', () async {
    await cubit.load();
    cubit.updateLocalRecords([_completedSession('ride-a', 7200, 28000)]);
    await Future<void>.delayed(Duration.zero);

    expect(gateway.recordCalls, 1);
    expect(gateway.recordedDuration, 7200);
    expect(gateway.recordedDistance, 28000);
    expect(gateway.loadEntriesCalls, 0);
  });

  test(
    'clears account-specific leaderboard state on account changes',
    () async {
      await cubit.load();
      await cubit.saveConsent(isOptedIn: true);
      cubit.clearForAccountChange();

      expect(cubit.state.settings, isNull);
      expect(cubit.state.entries, isEmpty);
      expect(cubit.state.error, isNull);
    },
  );
}

RideSessionSnapshot _completedSession(
  String id,
  int durationSeconds,
  double distanceMeters,
) {
  final startedAt = DateTime.utc(2026, 10, 12);
  return RideSessionSnapshot(
    id: id,
    startedAt: startedAt,
    endedAt: startedAt.add(Duration(seconds: durationSeconds)),
    status: RideSessionStatus.completed,
    totalPausedMilliseconds: 0,
    distanceMeters: distanceMeters,
    currentSpeedMetersPerSecond: 0,
  );
}

class _FakeLeaderboardGateway implements LeaderboardGateway {
  bool optedIn = false;
  int? recordedDuration;
  double? recordedDistance;
  int loadEntriesCalls = 0;
  int saveConsentCalls = 0;
  int recordCalls = 0;

  @override
  bool get isConfigured => true;

  @override
  bool get isSignedIn => true;

  @override
  Future<List<LeaderboardEntry>> loadEntries(
    LeaderboardCategory category,
  ) async {
    loadEntriesCalls++;
    return const [
      LeaderboardEntry(rank: 1, displayName: 'Rider Name', score: 7200),
    ];
  }

  @override
  Future<LeaderboardSettings> loadSettings() async => LeaderboardSettings(
    isOptedIn: optedIn,
    displayName: optedIn ? 'Rider Name' : null,
  );

  @override
  Future<void> saveConsent({required bool isOptedIn}) async {
    saveConsentCalls++;
    optedIn = isOptedIn;
  }

  @override
  Future<void> recordPersonalBest({
    required int durationSeconds,
    required double distanceMeters,
  }) async {
    recordCalls++;
    recordedDuration = durationSeconds;
    recordedDistance = distanceMeters;
  }
}
