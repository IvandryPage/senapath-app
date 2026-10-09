import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/data/custom_auth_session_manager.dart';
import '../domain/ride_ledger_block.dart';

abstract interface class RideLedgerSyncGateway {
  bool get isConfigured;
  bool get isSignedIn;

  Future<RideLedgerSyncResult> sync(List<RideLedgerBlock> blocks);
}

class RideLedgerSyncResult {
  const RideLedgerSyncResult({
    required this.blockCount,
    required this.head,
    required this.message,
  });

  final int blockCount;
  final String head;
  final String message;
}

class SupabaseRideLedgerSyncGateway implements RideLedgerSyncGateway {
  const SupabaseRideLedgerSyncGateway(this._client, this._sessionManager);

  final SupabaseClient? _client;
  final CustomAuthSessionManager _sessionManager;

  @override
  bool get isConfigured => _client != null;

  @override
  bool get isSignedIn => _sessionManager.currentUserId != null;

  @override
  Future<RideLedgerSyncResult> sync(List<RideLedgerBlock> blocks) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase belum dikonfigurasi.');
    }
    if (!isSignedIn) {
      throw StateError('Masuk ke akun online untuk menyinkronkan bukti.');
    }
    await _sessionManager.requireAccessToken();
    final response = await _sessionManager.invokeAuthenticatedFunction(
      'sync-ride-proofs',
      body: {
        'consent': true,
        'blocks': blocks.map((block) => block.toJson()).toList(),
      },
    );
    final data = response.data;
    if (response.status < 200 || response.status >= 300) {
      final message = data is Map ? data['error'] : null;
      throw StateError(
        message is String && message.isNotEmpty
            ? message
            : 'Sinkronisasi bukti gagal (HTTP ${response.status}).',
      );
    }
    if (data is! Map ||
        data['cloudSynced'] != true ||
        data['blockCount'] is! num ||
        data['head'] is! String ||
        data['message'] is! String) {
      throw const FormatException('Respons sinkronisasi ledger tidak valid.');
    }
    return RideLedgerSyncResult(
      blockCount: (data['blockCount'] as num).toInt(),
      head: data['head'] as String,
      message: data['message'] as String,
    );
  }
}
