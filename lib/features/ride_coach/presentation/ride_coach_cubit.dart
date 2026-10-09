import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/ride_coach_gateway.dart';

class RideCoachState {
  const RideCoachState({
    this.recommendation,
    this.isLoading = false,
    this.error,
    this.notice,
  });

  final String? recommendation;
  final bool isLoading;
  final String? error;
  final String? notice;
}

class RideCoachCubit extends Cubit<RideCoachState> {
  RideCoachCubit(this._gateway) : super(const RideCoachState());

  final RideCoachGateway _gateway;

  bool get isConfigured => _gateway.isConfigured;
  bool get isSignedIn => _gateway.isSignedIn;

  Future<void> recommend({
    required Map<String, Object?> rideContext,
    required bool consent,
  }) async {
    if (state.isLoading) return;
    emit(const RideCoachState(isLoading: true));
    try {
      final recommendation = await _gateway.recommend(
        rideContext: rideContext,
        consent: consent,
      );
      if (!isClosed) emit(RideCoachState(recommendation: recommendation));
    } catch (error) {
      if (!isClosed) {
        emit(
          RideCoachState(
            error: error is StateError ? error.message : 'Rekomendasi tidak tersedia. Periksa koneksi dan konfigurasi AI.',
          ),
        );
      }
    }
  }

  Future<void> diagnoseConfiguration() async {
    if (state.isLoading) return;
    emit(const RideCoachState(isLoading: true));
    try {
      final message = await _gateway.diagnoseConfiguration();
      if (!isClosed) emit(RideCoachState(notice: message));
    } catch (error) {
      if (!isClosed) {
        emit(
          RideCoachState(
            error: error is StateError
                ? error.message
                : 'Pemeriksaan konfigurasi Gemini gagal.',
          ),
        );
      }
    }
  }
}
