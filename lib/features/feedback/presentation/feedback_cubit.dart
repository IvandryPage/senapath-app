import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/feedback_gateway.dart';
import '../data/feedback_repository.dart';
import '../domain/feedback_submission.dart';

class FeedbackState {
  const FeedbackState({
    this.pending = const [],
    this.isLoaded = false,
    this.isLoading = false,
    this.isSubmitting = false,
    this.status,
    this.error,
  });

  final List<FeedbackSubmission> pending;
  final bool isLoaded;
  final bool isLoading;
  final bool isSubmitting;
  final String? status;
  final String? error;

  FeedbackState copyWith({
    List<FeedbackSubmission>? pending,
    bool? isLoaded,
    bool? isLoading,
    bool? isSubmitting,
    String? status,
    String? error,
    bool clearStatus = false,
    bool clearError = false,
  }) => FeedbackState(
    pending: pending ?? this.pending,
    isLoaded: isLoaded ?? this.isLoaded,
    isLoading: isLoading ?? this.isLoading,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    status: clearStatus ? null : status ?? this.status,
    error: clearError ? null : error ?? this.error,
  );
}

class FeedbackCubit extends Cubit<FeedbackState> {
  FeedbackCubit(this._repository, this._gateway) : super(const FeedbackState());

  final FeedbackRepository _repository;
  final FeedbackGateway _gateway;
  final Random _random = Random.secure();

  Future<void> load() async {
    if (state.isLoaded || state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      emit(
        state.copyWith(
          pending: await _repository.loadPending(),
          isLoaded: true,
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Feedback tersimpan tidak dapat dibaca.',
        ),
      );
    }
  }

  Future<bool> submit(String message, {required bool consent}) async {
    if (state.isSubmitting) return false;
    if (!consent) {
      emit(state.copyWith(error: 'Persetujuan diperlukan sebelum mengirim.'));
      return false;
    }
    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty || normalizedMessage.length > 4000) {
      emit(state.copyWith(error: 'Isi feedback harus 1 sampai 4000 karakter.'));
      return false;
    }
    if (!state.isLoaded) await load();
    if (!state.isLoaded || state.pending.length >= 20) {
      emit(
        state.copyWith(
          error: 'Feedback belum dapat disimpan. Periksa penyimpanan lokal.',
        ),
      );
      return false;
    }

    final now = DateTime.now().toUtc();
    final submission = FeedbackSubmission(
      id: '${now.microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}',
      message: normalizedMessage,
      createdAt: now,
      consentedAt: now,
    );
    final updatedPending = [...state.pending, submission];
    emit(
      state.copyWith(isSubmitting: true, clearError: true, clearStatus: true),
    );
    try {
      await _repository.savePending(updatedPending);
    } catch (_) {
      emit(
        state.copyWith(
          isSubmitting: false,
          error: 'Feedback gagal disimpan dengan aman di perangkat.',
        ),
      );
      return false;
    }

    emit(state.copyWith(pending: updatedPending));
    await _deliver(submission);
    return true;
  }

  Future<void> retry(String id) async {
    if (state.isSubmitting) return;
    FeedbackSubmission? submission;
    for (final item in state.pending) {
      if (item.id == id) submission = item;
    }
    if (submission == null) return;
    emit(
      state.copyWith(isSubmitting: true, clearError: true, clearStatus: true),
    );
    await _deliver(submission);
  }

  Future<void> _deliver(FeedbackSubmission submission) async {
    if (!_gateway.isConfigured) {
      emit(
        state.copyWith(
          isSubmitting: false,
          status: 'Belum terkirim. Feedback disimpan terenkripsi di perangkat sampai server tersedia.',
        ),
      );
      return;
    }

    try {
      await _gateway.submit(submission);
      final updatedPending = state.pending
          .where((item) => item.id != submission.id)
          .toList();
      await _repository.savePending(updatedPending);
      emit(
        state.copyWith(
          pending: updatedPending,
          isSubmitting: false,
          status: 'Feedback berhasil terkirim. Terima kasih.',
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isSubmitting: false,
          error: 'Feedback belum terkirim. Data tetap tersimpan terenkripsi; periksa login dan koneksi sebelum mencoba lagi.',
        ),
      );
    }
  }
}
