import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/leaderboard/data/leaderboard_gateway.dart';
import 'package:senapath/features/leaderboard/domain/leaderboard_models.dart';
import 'package:senapath/features/leaderboard/presentation/leaderboard_cubit.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

class FakeLeaderboardGateway implements LeaderboardGateway {
  FakeLeaderboardGateway({this.isConfigured = true, this.isSignedIn = true});

  @override
  final bool isConfigured;
  @override
  final bool isSignedIn;

  LeaderboardSettings settings = const LeaderboardSettings(
    isOptedIn: true,
    displayName: 'Budi',
  );
  final Map<LeaderboardCategory, List<LeaderboardEntry>> entries = {
    LeaderboardCategory.duration: const [
      LeaderboardEntry(rank: 1, displayName: 'Sari', score: 7200),
    ],
    LeaderboardCategory.distance: const [
      LeaderboardEntry(rank: 1, displayName: 'Rina', score: 90000),
    ],
  };

  final List<bool> consentWrites = [];
  final List<({int durationSeconds, double distanceMeters})> personalBests = [];
  Object? loadError;
  Object? consentError;

  @override
  Future<LeaderboardSettings> loadSettings() async {
    final failure = loadError;
    if (failure != null) throw failure;
    return settings;
  }

  @override
  Future<List<LeaderboardEntry>> loadEntries(LeaderboardCategory category) async {
    final failure = loadError;
    if (failure != null) throw failure;
    return entries[category] ?? const [];
  }

  @override
  Future<void> saveConsent({required bool isOptedIn}) async {
    final failure = consentError;
    if (failure != null) throw failure;
    consentWrites.add(isOptedIn);
    settings = LeaderboardSettings(isOptedIn: isOptedIn, displayName: 'Budi');
  }

  @override
  Future<void> recordPersonalBest({
    required int durationSeconds,
    required double distanceMeters,
  }) async {
    personalBests.add(
      (durationSeconds: durationSeconds, distanceMeters: distanceMeters),
    );
  }
}

RideSessionSnapshot _session({
  required String id,
  RideSessionStatus status = RideSessionStatus.completed,
  DateTime? endedAt,
  double distanceMeters = 10000,
}) => RideSessionSnapshot(
  id: id,
  startedAt: DateTime.utc(2026, 1, 5, 8),
  endedAt: endedAt ?? DateTime.utc(2026, 1, 5, 9),
  status: status,
  totalPausedMilliseconds: 0,
  distanceMeters: distanceMeters,
  currentSpeedMetersPerSecond: 0,
);

void main() {
  group('LeaderboardCubit.load', () {
    test('surfaces a message when the feature is not configured', () async {
      final cubit = LeaderboardCubit(FakeLeaderboardGateway(isConfigured: false));
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.error, 'Fitur akun online belum tersedia.');
      expect(cubit.state.entries, isEmpty);
    });

    test('asks the rider to sign in when signed out', () async {
      final cubit = LeaderboardCubit(FakeLeaderboardGateway(isSignedIn: false));
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.error, contains('Masuk ke akun online'));
    });

    test('loads entries for the selected category', () async {
      final gateway = FakeLeaderboardGateway();
      final cubit = LeaderboardCubit(gateway);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.settings?.isOptedIn, isTrue);
      expect(cubit.state.entries.single.displayName, 'Sari');
      expect(cubit.state.isLoading, isFalse);

      await cubit.selectCategory(LeaderboardCategory.distance);
      expect(cubit.state.category, LeaderboardCategory.distance);
      expect(cubit.state.entries.single.displayName, 'Rina');
    });

    test('skips entries while opted out', () async {
      final gateway = FakeLeaderboardGateway()
        ..settings = const LeaderboardSettings(isOptedIn: false, displayName: null);
      final cubit = LeaderboardCubit(gateway);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.entries, isEmpty);
      expect(cubit.state.error, isNull);
    });

    test('reports a friendly error when loading fails', () async {
      final gateway = FakeLeaderboardGateway()..loadError = StateError('down');
      final cubit = LeaderboardCubit(gateway);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.error, contains('Papan peringkat tidak dapat dimuat'));
      expect(cubit.state.isLoading, isFalse);
    });
  });

  group('LeaderboardCubit.saveConsent', () {
    test('opting out clears the entries and confirms', () async {
      final gateway = FakeLeaderboardGateway();
      final cubit = LeaderboardCubit(gateway);
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.saveConsent(isOptedIn: false);
      expect(gateway.consentWrites, [false]);
      expect(cubit.state.entries, isEmpty);
      expect(cubit.state.message, contains('berhenti ikut'));
      expect(cubit.state.isSaving, isFalse);
    });

    test('opting in reloads the entries', () async {
      final gateway = FakeLeaderboardGateway()
        ..settings = const LeaderboardSettings(isOptedIn: false, displayName: null);
      final cubit = LeaderboardCubit(gateway);
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.saveConsent(isOptedIn: true);
      expect(cubit.state.entries, hasLength(1));
      expect(cubit.state.message, contains('sudah ikut'));
    });

    test('reports a friendly error when saving fails', () async {
      final gateway = FakeLeaderboardGateway()
        ..consentError = StateError('down');
      final cubit = LeaderboardCubit(gateway);
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.saveConsent(isOptedIn: false);
      expect(cubit.state.error, contains('tidak dapat disimpan'));
    });
  });

  group('LeaderboardCubit.updateLocalRecords', () {
    test('tracks the longest completed session and syncs it', () async {
      final gateway = FakeLeaderboardGateway();
      final cubit = LeaderboardCubit(gateway);
      addTearDown(cubit.close);
      await cubit.load();

      cubit.updateLocalRecords([
        _session(id: 's1', distanceMeters: 20000),
        _session(
          id: 's2',
          endedAt: DateTime.utc(2026, 1, 5, 12),
          distanceMeters: 50000,
        ),
        _session(
          id: 'recording',
          status: RideSessionStatus.recording,
          distanceMeters: 999999,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(gateway.personalBests, hasLength(1));
      expect(gateway.personalBests.single.durationSeconds, 4 * 3600);
      expect(gateway.personalBests.single.distanceMeters, 50000);
      expect(cubit.state.message, contains('tersinkron'));
    });

    test('ignores implausibly long or long-distance sessions', () async {
      final gateway = FakeLeaderboardGateway();
      final cubit = LeaderboardCubit(gateway);
      addTearDown(cubit.close);
      await cubit.load();

      cubit.updateLocalRecords([
        _session(
          id: 's1',
          endedAt: DateTime.utc(2026, 1, 8),
          distanceMeters: 2000000,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(gateway.personalBests, isEmpty);
    });

    test('reports a sync failure', () async {
      final gateway = FakeLeaderboardGateway();
      final failing = _FailingOnceGateway(gateway);
      final cubit = LeaderboardCubit(failing);
      addTearDown(cubit.close);
      await cubit.load();

      cubit.updateLocalRecords([_session(id: 's1')]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.error, contains('belum tersinkron'));
      expect(gateway.personalBests, isEmpty, reason: 'the first write failed');
    });

    test('does nothing when signed out', () async {
      final gateway = FakeLeaderboardGateway(isSignedIn: false);
      final cubit = LeaderboardCubit(gateway);
      addTearDown(cubit.close);

      cubit.updateLocalRecords([_session(id: 's1')]);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.personalBests, isEmpty);
    });
  });

  test('clearForAccountChange resets state', () async {
    final gateway = FakeLeaderboardGateway();
    final cubit = LeaderboardCubit(gateway);
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.settings, isNotNull);

    cubit.clearForAccountChange();
    expect(cubit.state.settings, isNull);
    expect(cubit.state.entries, isEmpty);
    expect(cubit.state.category, LeaderboardCategory.duration);
  });
}

/// Wraps [inner] so the first personal-best write fails once.
class _FailingOnceGateway implements LeaderboardGateway {
  _FailingOnceGateway(this.inner);

  final FakeLeaderboardGateway inner;
  var _failed = false;

  @override
  bool get isConfigured => inner.isConfigured;

  @override
  bool get isSignedIn => inner.isSignedIn;

  @override
  Future<LeaderboardSettings> loadSettings() => inner.loadSettings();

  @override
  Future<List<LeaderboardEntry>> loadEntries(LeaderboardCategory category) =>
      inner.loadEntries(category);

  @override
  Future<void> saveConsent({required bool isOptedIn}) =>
      inner.saveConsent(isOptedIn: isOptedIn);

  @override
  Future<void> recordPersonalBest({
    required int durationSeconds,
    required double distanceMeters,
  }) {
    if (!_failed) {
      _failed = true;
      return Future.error(StateError('offline'));
    }
    return inner.recordPersonalBest(
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
    );
  }
}
