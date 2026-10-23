import '../../account_sync/data/account_cloud_gateway.dart';
import '../domain/ride_session.dart';
import 'ride_session_repository.dart';

/// Mendorong sesi selesai ke cloud akun dan memulihkannya di perangkat lain.
class RideSessionCloudSync {
  /// Membuat layanan sinkronisasi cloud sesi.
  const RideSessionCloudSync({required this.repository, required this.gateway});

  final DriftRideSessionRepository repository;
  final AccountCloudGateway gateway;

  /// Menentukan apakah sinkronisasi cloud tersedia.
  bool get canSync => gateway.isConfigured && gateway.isSignedIn;

  /// Mengirim sesi ke cloud.
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

  /// Mengambil sesi dari cloud dan menyimpannya lokal.
  /// 
  /// Returns the number of sessions imported/updated from cloud.
  /// This method is called after sign-in to restore all cloud data to the device.
  Future<int> pullSessions({bool Function()? shouldContinue}) async {
    if (!canSync) {
      // Debug: Gateway not configured or user not signed in
      return 0;
    }
    
    final remote = await gateway.pullRideSessions();
    // Debug: Retrieved ${remote.length} sessions from cloud
    
    var imported = 0;
    for (final item in remote) {
      if (shouldContinue != null && !shouldContinue()) break;
      
      // Upsert will merge cloud data with local data
      // If session exists locally, it will be updated
      // If session doesn't exist, it will be inserted
      await repository.upsertCloudSession(item.session, item.points);
      imported++;
    }
    
    // Debug: Successfully imported $imported sessions from cloud
    return imported;
  }

  /// Menghapus sesi dari cloud.
  Future<void> deleteSession(String sessionId) async {
    if (!canSync) return;
    await gateway.deleteRideSession(sessionId);
  }
}
