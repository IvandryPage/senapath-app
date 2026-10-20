import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/session/data/ride_session_repository.dart';
import 'package:senapath/features/session/data/session_sync_coordinator.dart';
import 'package:senapath/features/session/data/session_sync_gateway.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

class FakeRideSessionRepository implements RideSessionRepository {
  FakeRideSessionRepository({this._summary});

  RideSessionSummary? _summary;
  final List<String> syncStatusUpdates = [];

  set summary(RideSessionSummary value) => _summary = value;

  @override
  Future<RideSessionSummary> loadSummary(String sessionId) async {
    final summary = _summary;
    if (summary == null) throw StateError('missing summary');
    return summary;
  }

  @override
  Future<void> updateSyncStatus(String sessionId, String status) async {
    syncStatusUpdates.add(status);
  }

  @override
  Future<RideSessionSnapshot?> recoverCurrentSession() => throw UnimplementedError();

  @override
  Future<List<RideSessionSnapshot>> loadCompletedSessions() =>
      throw UnimplementedError();

  @override
  Future<RideSessionSnapshot> updateActivityMetadata({
    required String sessionId,
    required String title,
    required RideActivityType activityType,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteCompletedSession(String sessionId) => throw UnimplementedError();

  @override
  Future<List<TelemetryLocation>> loadTelemetryLocations(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<RideSessionSnapshot> start(DateTime now) => throw UnimplementedError();

  @override
  Future<RideSessionSnapshot> pause(String sessionId, DateTime now) =>
      throw UnimplementedError();

  @override
  Future<RideSessionSnapshot> resume(String sessionId, DateTime now) =>
      throw UnimplementedError();

  @override
  Future<RideSessionSnapshot> finish(String sessionId, DateTime now) =>
      throw UnimplementedError();

  @override
  Future<TelemetryLocation?> latestLocation(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<RideSessionSnapshot?> recordLocation({
    required String sessionId,
    required TelemetryLocation location,
    required double addedDistanceMeters,
  }) => throw UnimplementedError();
}

class FakeSessionSyncGateway implements SessionSyncGateway {
  FakeSessionSyncGateway({
    this.isConfigured = true,
    this.isSignedIn = true,
    this.error,
  });

  @override
  final bool isConfigured;
  @override
  final bool isSignedIn;

  final List<String> uploadedSessionIds = [];
  final Object? error;
  String? shareWithTeamId;

  @override
  Future<void> uploadSummary(
    RideSessionSummary summary, {
    String? shareWithTeamId,
  }) async {
    this.shareWithTeamId = shareWithTeamId;
    final failure = error;
    if (failure != null) throw failure;
    uploadedSessionIds.add(summary.session.id);
  }
}

RideSessionSummary _summary(RideSessionStatus status) => RideSessionSummary(
  session: RideSessionSnapshot(
    id: 's1',
    startedAt: DateTime.utc(2026, 1, 5),
    endedAt: DateTime.utc(2026, 1, 5, 1),
    status: status,
    totalPausedMilliseconds: 0,
    distanceMeters: 20000,
    currentSpeedMetersPerSecond: 8,
  ),
  sampleCount: 10,
  speedSamples: const [],
  elevationSource: 'gps',
);

void main() {
  group('SessionSyncCoordinator.syncSummary', () {
    test('requires sync consent', () async {
      final coordinator = SessionSyncCoordinator(
        repository: FakeRideSessionRepository(),
        gateway: FakeSessionSyncGateway(),
      );

      expect(
        () => coordinator.syncSummary('s1', consented: false),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Persetujuan'),
          ),
        ),
      );
    });

    test('requires a configured and signed-in gateway', () async {
      final notConfigured = SessionSyncCoordinator(
        repository: FakeRideSessionRepository(),
        gateway: FakeSessionSyncGateway(isConfigured: false),
      );
      expect(
        () => notConfigured.syncSummary('s1', consented: true),
        throwsA(isA<StateError>()),
      );

      final signedOut = SessionSyncCoordinator(
        repository: FakeRideSessionRepository(),
        gateway: FakeSessionSyncGateway(isSignedIn: false),
      );
      expect(
        () => signedOut.syncSummary('s1', consented: true),
        throwsA(isA<StateError>()),
      );
    });

    test('only syncs completed sessions', () async {
      final repository = FakeRideSessionRepository(
        summary: _summary(RideSessionStatus.recording),
      );
      final coordinator = SessionSyncCoordinator(
        repository: repository,
        gateway: FakeSessionSyncGateway(),
      );

      expect(
        () => coordinator.syncSummary('s1', consented: true),
        throwsA(isA<StateError>()),
      );
      expect(repository.syncStatusUpdates, isEmpty);
    });

    test('marks the session syncing then synced', () async {
      final repository = FakeRideSessionRepository(
        summary: _summary(RideSessionStatus.completed),
      );
      final gateway = FakeSessionSyncGateway();
      final coordinator = SessionSyncCoordinator(
        repository: repository,
        gateway: gateway,
      );

      await coordinator.syncSummary('s1', consented: true, shareWithTeamId: 't1');

      expect(repository.syncStatusUpdates, ['syncing', 'synced']);
      expect(gateway.uploadedSessionIds, ['s1']);
      expect(gateway.shareWithTeamId, 't1');
    });

    test('keeps the session pending when the caller stops early', () async {
      final repository = FakeRideSessionRepository(
        summary: _summary(RideSessionStatus.completed),
      );
      final coordinator = SessionSyncCoordinator(
        repository: repository,
        gateway: FakeSessionSyncGateway(),
      );

      await coordinator.syncSummary(
        's1',
        consented: true,
        shouldContinue: () => false,
      );

      expect(repository.syncStatusUpdates, ['syncing', 'pending']);
    });

    test('marks the session failed when the upload throws', () async {
      final repository = FakeRideSessionRepository(
        summary: _summary(RideSessionStatus.completed),
      );
      final coordinator = SessionSyncCoordinator(
        repository: repository,
        gateway: FakeSessionSyncGateway(error: StateError('boom')),
      );

      await expectLater(
        coordinator.syncSummary('s1', consented: true),
        throwsA(isA<StateError>()),
      );
      expect(repository.syncStatusUpdates, ['syncing', 'failed']);
    });
  });
}
