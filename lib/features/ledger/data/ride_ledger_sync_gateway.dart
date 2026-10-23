import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/data/custom_auth_session_manager.dart';
import '../domain/ride_ledger_anchor.dart';
import '../domain/ride_ledger_block.dart';

/// Gateway sinkronisasi buku besar ke cloud dan blockchain.
abstract interface class RideLedgerSyncGateway {
  /// Menentukan apakah gateway terkonfigurasi.
  bool get isConfigured;
  /// Menentukan apakah pengguna telah masuk.
  bool get isSignedIn;

  /// Menyinkronkan daftar blok ke cloud.
  Future<RideLedgerSyncResult> sync(List<RideLedgerBlock> blocks);

  /// Mencatat head hash cloud ke blockchain melalui relayer server-side.
  Future<RideLedgerAnchorList> anchor();

  /// Daftar anchor (status transaksi disegarkan dari node RPC oleh server).
  Future<RideLedgerAnchorList> anchors();
}

/// Hasil sinkronisasi ledger ke cloud.
class RideLedgerSyncResult {
  /// Membuat hasil sinkronisasi ledger.
  const RideLedgerSyncResult({
    required this.blockCount,
    required this.head,
    required this.message,
  });

  final int blockCount;
  final String head;
  final String message;
}

/// Implementasi gateway sinkronisasi ledger berbasis Supabase.
class SupabaseRideLedgerSyncGateway implements RideLedgerSyncGateway {
  /// Membuat gateway sinkronisasi ledger Supabase.
  const SupabaseRideLedgerSyncGateway(this._client, this._sessionManager);

  final SupabaseClient? _client;
  final CustomAuthSessionManager _sessionManager;

  /// Menentukan apakah klien Supabase tersedia.
  @override
  bool get isConfigured => _client != null;

  /// Menentukan apakah pengguna telah masuk.
  @override
  bool get isSignedIn => _sessionManager.currentUserId != null;

  /// Menyinkronkan blok bukti ke cloud melalui fungsi terautentikasi.
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

  /// Mencatat anchor ke blockchain melalui relayer.
  @override
  Future<RideLedgerAnchorList> anchor() => _callAnchorFunction('anchor');

  /// Mengambil daftar anchor blockchain.
  @override
  Future<RideLedgerAnchorList> anchors() => _callAnchorFunction('list');

  /// Memanggil fungsi anchor terautentikasi.
  Future<RideLedgerAnchorList> _callAnchorFunction(String action) async {
    if (_client == null) {
      throw StateError('Supabase belum dikonfigurasi.');
    }
    if (!isSignedIn) {
      throw StateError('Masuk ke akun online untuk memakai blockchain.');
    }
    final response = await _sessionManager.invokeAuthenticatedFunction(
      'anchor-ride-proofs',
      body: {'action': action, if (action == 'anchor') 'consent': true},
    );
    final data = response.data;
    if (response.status < 200 || response.status >= 300) {
      final message = data is Map ? data['error'] : null;
      throw StateError(
        message is String && message.isNotEmpty
            ? message
            : 'Pencatatan blockchain gagal (HTTP ${response.status}).',
      );
    }
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respons anchor blockchain tidak valid.');
    }
    return RideLedgerAnchorList.fromJson(data);
  }
}
