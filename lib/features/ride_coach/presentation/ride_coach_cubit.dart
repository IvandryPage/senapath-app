import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/ride_coach_gateway.dart';

class RideCoachState {
  /// Membuat status pelatih AI untuk sesi dan briefing pra-perjalanan.
  const RideCoachState({
    this.recommendation,
    this.isLoading = false,
    this.error,
    this.notice,
    this.preRideBriefing,
    this.preRideRouteId,
    this.isLoadingPreRide = false,
    this.preRideError,
  });

  final String? recommendation;
  final bool isLoading;
  final String? error;
  final String? notice;
  final String? preRideBriefing;
  final String? preRideRouteId;
  final bool isLoadingPreRide;
  final String? preRideError;
}

class RideCoachCubit extends Cubit<RideCoachState> {
  /// Membuat cubit dengan [gateway] sebagai penyedia layanan AI.
  RideCoachCubit(this._gateway) : super(const RideCoachState());

  final RideCoachGateway _gateway;
  int _requestGeneration = 0;
  String? _activeSessionId;
  String? _consentedSessionId;
  DateTime? _lastRequestAt;

  /// Menandakan layanan pelatih AI sudah dikonfigurasi.
  bool get isConfigured => _gateway.isConfigured;

  /// Menandakan pengguna sudah masuk ke akun online.
  bool get isSignedIn => _gateway.isSignedIn;

  /// Waktu permintaan saran terakhir untuk sesi aktif.
  DateTime? get lastRequestAt => _lastRequestAt;

  /// Memeriksa apakah sesi [sessionId] sudah mendapat persetujuan pengguna.
  bool hasConsentForSession(String sessionId) =>
      _consentedSessionId == sessionId;

  /// Memberi persetujuan untuk sesi aktif dan mengembalikan status berhasil.
  bool grantConsentForSession(String sessionId) {
    if (_activeSessionId != sessionId) return false;
    _consentedSessionId = sessionId;
    return true;
  }

  /// Mengganti sesi aktif dan mereset persetujuan serta waktu permintaan.
  void setActiveSession(String? sessionId) {
    if (_activeSessionId == sessionId) return;
    _activeSessionId = sessionId;
    _consentedSessionId = null;
    _lastRequestAt = null;
    clearRecommendation();
  }

  /// Mencatat waktu mulai permintaan untuk sesi aktif [sessionId].
  void markRequestStarted(String sessionId) {
    if (_activeSessionId == sessionId) _lastRequestAt = DateTime.now();
  }

  /// Meminta saran AI dan memperbarui status pemuatan serta kesalahan.
  Future<void> recommend({
    required Map<String, Object?> rideContext,
    required bool consent,
  }) async {
    if (state.isLoading) return;
    final generation = ++_requestGeneration;
    emit(RideCoachState(recommendation: state.recommendation, isLoading: true));
    try {
      final recommendation = await _gateway.recommend(
        rideContext: rideContext,
        consent: consent,
      );
      if (!isClosed && generation == _requestGeneration) {
        emit(RideCoachState(recommendation: recommendation));
      }
    } catch (error) {
      if (!isClosed && generation == _requestGeneration) {
        emit(
          RideCoachState(
            recommendation: state.recommendation,
            error: error is StateError ? error.message : 'Saran belum tersedia. Periksa koneksi internet dan coba lagi.',
          ),
        );
      }
    }
  }

  /// Meminta briefing rute [routeId] dan menyimpan hasil atau kesalahannya.
  Future<void> prepareRide({
    required String routeId,
    required Map<String, Object?> routeAndWeather,
    required bool consent,
  }) async {
    if (state.isLoading || state.isLoadingPreRide) return;
    final generation = ++_requestGeneration;
    emit(
      RideCoachState(
        recommendation: state.recommendation,
        isLoading: state.isLoading,
        preRideBriefing: state.preRideBriefing,
        preRideRouteId: routeId,
        isLoadingPreRide: true,
      ),
    );
    try {
      final briefing = await _gateway.prepareRide(
        routeAndWeather: routeAndWeather,
        consent: consent,
      );
      if (!isClosed && generation == _requestGeneration) {
        emit(
          RideCoachState(
            recommendation: state.recommendation,
            preRideBriefing: briefing,
            preRideRouteId: routeId,
          ),
        );
      }
    } catch (error) {
      if (!isClosed && generation == _requestGeneration) {
        emit(
          RideCoachState(
            recommendation: state.recommendation,
            preRideBriefing: state.preRideBriefing,
            preRideRouteId: routeId,
            preRideError: error is StateError ? error.message : 'Briefing belum tersedia. Periksa koneksi internet dan coba lagi.',
          ),
        );
      }
    }
  }

  /// Membatalkan permintaan berjalan dan mengosongkan status pelatih.
  void clearRecommendation() {
    _requestGeneration++;
    emit(const RideCoachState());
  }

  /// Memeriksa konfigurasi layanan AI dan menampilkan hasilnya sebagai notice.
  Future<void> diagnoseConfiguration() async {
    if (state.isLoading) return;
    final generation = ++_requestGeneration;
    emit(const RideCoachState(isLoading: true));
    try {
      final message = await _gateway.diagnoseConfiguration();
      if (!isClosed && generation == _requestGeneration) {
        emit(RideCoachState(notice: message));
      }
    } catch (error) {
      if (!isClosed && generation == _requestGeneration) {
        emit(
          RideCoachState(
            error: error is StateError
                ? error.message
                : 'Asisten belum siap. Coba lagi nanti.',
          ),
        );
      }
    }
  }
}
