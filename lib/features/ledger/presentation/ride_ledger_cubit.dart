import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/ride_ledger_repository.dart';
import '../domain/ride_ledger_block.dart';

class RideLedgerState {
  const RideLedgerState({
    this.blocks = const [],
    this.isLoading = false,
    this.isVerified,
    this.error,
  });

  final List<RideLedgerBlock> blocks;
  final bool isLoading;
  final bool? isVerified;
  final String? error;
}

class RideLedgerCubit extends Cubit<RideLedgerState> {
  RideLedgerCubit(this._repository) : super(const RideLedgerState());

  final RideLedgerRepository _repository;

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
}
