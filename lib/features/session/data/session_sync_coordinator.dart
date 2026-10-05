import '../domain/ride_session.dart';
import 'ride_session_repository.dart';
import 'session_sync_gateway.dart';

class SessionSyncCoordinator {
  const SessionSyncCoordinator({
    required this.repository,
    required this.gateway,
  });

  final RideSessionRepository repository;
  final SessionSyncGateway gateway;

  Future<void> syncSummary(
    String sessionId, {
    required bool consented,
  }) async {
    if (!consented) {
      throw StateError('Persetujuan sinkronisasi diperlukan.');
    }
    if (!gateway.isConfigured) {
      throw StateError('Supabase belum dikonfigurasi.');
    }
    if (!gateway.isSignedIn) {
      throw StateError('Masuk ke akun online sebelum menyinkronkan sesi.');
    }

    final summary = await repository.loadSummary(sessionId);
    if (summary.session.status != RideSessionStatus.completed) {
      throw StateError('Hanya ringkasan sesi selesai yang dapat disinkronkan.');
    }

    await repository.updateSyncStatus(sessionId, 'syncing');
    try {
      await gateway.uploadSummary(summary);
      await repository.updateSyncStatus(sessionId, 'synced');
    } catch (_) {
      await repository.updateSyncStatus(sessionId, 'failed');
      rethrow;
    }
  }
}
