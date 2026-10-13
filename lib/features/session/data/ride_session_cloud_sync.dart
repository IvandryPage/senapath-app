import '../../account_sync/data/account_cloud_gateway.dart';
import '../domain/ride_session.dart';
import 'ride_session_repository.dart';

/// Pushes completed rides (metadata plus telemetry) to the account cloud and
/// restores them on any signed-in device.
class RideSessionCloudSync {
  const RideSessionCloudSync({required this.repository, required this.gateway});

  final DriftRideSessionRepository repository;
  final AccountCloudGateway gateway;

  bool get canSync => gateway.isConfigured && gateway.isSignedIn;

  Future<bool> pushSession(
    String sessionId, {
    bool Function()? shouldContinue,
  }) async {
    if (!canSync) return false;
    final summary = await repository.loadSummary(sessionId);
    if (summary.session.status != RideSessionStatus.completed) return false;

    await repository.updateSyncStatus(sessionId, 'syncing');
    try {
      if (shouldContinue != null && !shouldContinue()) {
        await repository.updateSyncStatus(sessionId, 'pending');
        return false;
      }
      final points = await repository.loadTelemetryLocations(sessionId);
      await gateway.pushRideSession(summary.session, points);
      if (shouldContinue != null && !shouldContinue()) {
        await repository.updateSyncStatus(sessionId, 'pending');
        return false;
      }
      await repository.updateSyncStatus(sessionId, 'synced');
      return true;
    } catch (_) {
      final cancelled = shouldContinue != null && !shouldContinue();
      await repository.updateSyncStatus(
        sessionId,
        cancelled ? 'pending' : 'failed',
      );
      rethrow;
    }
  }

  Future<int> pullSessions({bool Function()? shouldContinue}) async {
    if (!canSync) return 0;
    final remote = await gateway.pullRideSessions();
    var imported = 0;
    for (final item in remote) {
      if (shouldContinue != null && !shouldContinue()) break;
      await repository.upsertCloudSession(item.session, item.points);
      imported++;
    }
    return imported;
  }

  Future<void> deleteSession(String sessionId) async {
    if (!canSync) return;
    await gateway.deleteRideSession(sessionId);
  }
}
