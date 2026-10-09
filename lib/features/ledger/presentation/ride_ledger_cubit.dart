import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/ride_ledger_repository.dart';
import '../data/ride_ledger_sync_gateway.dart';
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
  });

  final List<RideLedgerBlock> blocks;
  final bool isLoading;
  final bool? isVerified;
  final String? error;
  final String? message;
  final bool isSyncing;
  final int? cloudBlockCount;
}

class RideLedgerCubit extends Cubit<RideLedgerState> {
  RideLedgerCubit(this._repository, {this.syncGateway})
    : super(const RideLedgerState());

  final RideLedgerRepository _repository;
  final RideLedgerSyncGateway? syncGateway;

  bool get canSync =>
      syncGateway?.isConfigured == true && syncGateway?.isSignedIn == true;

  Future<void> load() async {
    emit(
      RideLedgerState(
        blocks: state.blocks,
        isLoading: true,
        isVerified: state.isVerified,
      ),
    );
    try {
      final blocks = await _repository.loadBlocks();
      final verified = await _repository.verify();
      if (!isClosed) {
        emit(RideLedgerState(blocks: blocks, isVerified: verified));
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          RideLedgerState(
            blocks: state.blocks,
            error: 'Rantai bukti perjalanan tidak dapat dibaca.',
          ),
        );
      }
    }
  }

  Future<void> verify() async {
    try {
      final verified = await _repository.verify();
      if (!isClosed) {
        emit(
          RideLedgerState(
            blocks: await _repository.loadBlocks(),
            isVerified: verified,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          RideLedgerState(
            blocks: state.blocks,
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
      emit(
        RideLedgerState(
          blocks: state.blocks,
          isVerified: state.isVerified,
          error: gateway?.isConfigured == true
              ? 'Masuk ke akun online untuk menyinkronkan bukti.'
              : 'Konfigurasi akun cloud belum tersedia.',
        ),
      );
      return;
    }
    emit(
      RideLedgerState(
        blocks: state.blocks,
        isVerified: state.isVerified,
        isSyncing: true,
      ),
    );
    try {
      final blocks = await _repository.loadBlocks();
      final verified = await _repository.verify();
      if (!verified) {
        throw StateError('Rantai lokal tidak valid. Perbaiki sebelum sinkron.');
      }
      final result = await gateway.sync(blocks);
      if (!isClosed) {
        emit(
          RideLedgerState(
            blocks: blocks,
            isVerified: true,
            cloudBlockCount: result.blockCount,
            message: result.message,
          ),
        );
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          RideLedgerState(
            blocks: state.blocks,
            isVerified: state.isVerified,
            error: error is StateError
                ? error.message
                : 'Ledger tidak dapat disinkronkan. Periksa koneksi dan coba lagi.',
          ),
        );
      }
    }
  }
}
