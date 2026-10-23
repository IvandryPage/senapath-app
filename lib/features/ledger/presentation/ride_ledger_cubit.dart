import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/evm_rpc_client.dart';
import '../data/ride_ledger_anchor_verifier.dart';
import '../data/ride_ledger_repository.dart';
import '../data/ride_ledger_sync_gateway.dart';
import '../domain/ride_ledger_anchor.dart';
import '../domain/ride_ledger_block.dart';

class RideLedgerState {
  const RideLedgerState({
    this.blocks = const [],
    this.isLoading = false,
    this.isVerified,
    this.error,
    this.message,
    this.isSyncing = false,
    this.cloudBlockCount,
    this.chain,
    this.anchors = const [],
    this.isAnchoring = false,
    this.verifyingAnchorId,
    this.verifications = const {},
  });

  final List<RideLedgerBlock> blocks;
  final bool isLoading;
  final bool? isVerified;
  final String? error;
  final String? message;
  final bool isSyncing;
  final int? cloudBlockCount;
  final RideLedgerChainInfo? chain;
  final List<RideLedgerAnchor> anchors;
  final bool isAnchoring;
  final String? verifyingAnchorId;

  /// Hasil verifikasi RPC per id anchor.
  final Map<String, AnchorVerification> verifications;

  /// Menyalin state; `error` dan `message` selalu direset kecuali diberikan.
  RideLedgerState copyWith({
    List<RideLedgerBlock>? blocks,
    bool? isLoading,
    bool? isVerified,
    String? error,
    String? message,
    bool? isSyncing,
    int? cloudBlockCount,
    RideLedgerChainInfo? chain,
    List<RideLedgerAnchor>? anchors,
    bool? isAnchoring,
    String? verifyingAnchorId,
    bool clearVerifyingAnchor = false,
    Map<String, AnchorVerification>? verifications,
  }) => RideLedgerState(
    blocks: blocks ?? this.blocks,
    isLoading: isLoading ?? false,
    isVerified: isVerified ?? this.isVerified,
    error: error,
    message: message,
    isSyncing: isSyncing ?? false,
    cloudBlockCount: cloudBlockCount ?? this.cloudBlockCount,
    chain: chain ?? this.chain,
    anchors: anchors ?? this.anchors,
    isAnchoring: isAnchoring ?? false,
    verifyingAnchorId: clearVerifyingAnchor
        ? null
        : verifyingAnchorId ?? this.verifyingAnchorId,
    verifications: verifications ?? this.verifications,
  );
}

class RideLedgerCubit extends Cubit<RideLedgerState> {
  RideLedgerCubit(
    this._repository, {
    this.syncGateway,
    this.verifier = const RideLedgerAnchorVerifier(),
    EvmRpcClient Function(String rpcUrl)? rpcFactory,
  }) : _rpcFactory = rpcFactory ?? EvmRpcClient.new,
       super(const RideLedgerState());

  final RideLedgerRepository _repository;
  final RideLedgerSyncGateway? syncGateway;
  final RideLedgerAnchorVerifier verifier;
  final EvmRpcClient Function(String rpcUrl) _rpcFactory;

  bool get canSync =>
      syncGateway?.isConfigured == true && syncGateway?.isSignedIn == true;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    try {
      final blocks = await _repository.loadBlocks();
      final verified = await _repository.verify();
      if (!isClosed) {
        emit(state.copyWith(blocks: blocks, isVerified: verified));
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(error: 'Rantai bukti perjalanan tidak dapat dibaca.'),
        );
      }
      return;
    }
    await refreshAnchors();
  }

  /// Memuat daftar anchor blockchain; kegagalan tidak mengganggu ledger lokal.
  Future<void> refreshAnchors() async {
    final gateway = syncGateway;
    if (gateway == null || !canSync) return;
    try {
      final result = await gateway.anchors();
      if (!isClosed) {
        emit(state.copyWith(chain: result.chain, anchors: result.anchors));
      }
    } catch (_) {
      // Anchor bersifat tambahan; ledger lokal tetap dapat dipakai.
    }
  }

  Future<void> verify() async {
    try {
      final verified = await _repository.verify();
      final blocks = await _repository.loadBlocks();
      if (!isClosed) {
        emit(state.copyWith(blocks: blocks, isVerified: verified));
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isVerified: false,
            error: 'Verifikasi rantai bukti gagal.',
          ),
        );
      }
    }
  }

  Future<void> sync() async {
    final gateway = syncGateway;
    if (gateway == null || !gateway.isConfigured || !gateway.isSignedIn) {
      emit(state.copyWith(error: _unavailableMessage(gateway)));
      return;
    }
    emit(state.copyWith(isSyncing: true));
    try {
      final blocks = await _repository.loadBlocks();
      await _requireVerified();
      final result = await gateway.sync(blocks);
      if (!isClosed) {
        emit(
          state.copyWith(
            blocks: blocks,
            isVerified: true,
            cloudBlockCount: result.blockCount,
            message: result.message,
          ),
        );
      }
    } catch (error) {
      if (!isClosed) emit(state.copyWith(error: _errorText(error)));
    }
  }

  /// Menyinkronkan ledger ke cloud lalu mencatat head hash ke blockchain.
  Future<void> anchor() async {
    final gateway = syncGateway;
    if (gateway == null || !gateway.isConfigured || !gateway.isSignedIn) {
      emit(state.copyWith(error: _unavailableMessage(gateway)));
      return;
    }
    emit(state.copyWith(isAnchoring: true));
    try {
      final blocks = await _repository.loadBlocks();
      await _requireVerified();
      final synced = await gateway.sync(blocks);
      final result = await gateway.anchor();
      if (!isClosed) {
        emit(
          state.copyWith(
            blocks: blocks,
            isVerified: true,
            cloudBlockCount: synced.blockCount,
            chain: result.chain,
            anchors: result.anchors,
            message:
                'Head ledger dikirim ke ${result.chain.name}. Konfirmasi '
                'biasanya butuh beberapa detik; tekan segarkan untuk '
                'memperbarui status.',
          ),
        );
      }
    } catch (error) {
      if (!isClosed) emit(state.copyWith(error: _errorText(error)));
    }
  }

  /// Verifikasi independen: membaca transaksi langsung dari RPC publik dan
  /// mencocokkannya dengan ledger lokal.
  Future<void> verifyAnchor(RideLedgerAnchor anchor) async {
    final chain = state.chain;
    if (chain == null) return;
    emit(state.copyWith(verifyingAnchorId: anchor.id));
    final rpc = _rpcFactory(chain.publicRpcUrl);
    try {
      final result = await verifier.verify(
        anchor: anchor,
        chain: chain,
        localBlocks: state.blocks,
        rpc: rpc,
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            clearVerifyingAnchor: true,
            verifications: {...state.verifications, anchor.id: result},
          ),
        );
      }
    } finally {
      rpc.close();
    }
  }

  Future<void> _requireVerified() async {
    if (!await _repository.verify()) {
      throw StateError(
        'Data bukti tidak cocok. Periksa sebelum menyimpan online.',
      );
    }
  }

  String _unavailableMessage(RideLedgerSyncGateway? gateway) =>
      gateway?.isConfigured == true
      ? 'Masuk ke akun online untuk menyinkronkan bukti.'
      : 'Fitur akun online belum tersedia.';

  String _errorText(Object error) => error is StateError
      ? error.message
      : 'Bukti tidak dapat diproses. Periksa koneksi dan coba lagi.';
}
