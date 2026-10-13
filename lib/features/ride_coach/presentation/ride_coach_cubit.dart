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
  int _requestGeneration = 0;
  String? _activeSessionId;
  String? _consentedSessionId;
  DateTime? _lastRequestAt;

  bool get isConfigured => _gateway.isConfigured;
  bool get isSignedIn => _gateway.isSignedIn;
  DateTime? get lastRequestAt => _lastRequestAt;

  bool hasConsentForSession(String sessionId) =>
      _consentedSessionId == sessionId;

  bool grantConsentForSession(String sessionId) {
    if (_activeSessionId != sessionId) return false;
    _consentedSessionId = sessionId;
    return true;
  }

  void setActiveSession(String? sessionId) {
    if (_activeSessionId == sessionId) return;
    _activeSessionId = sessionId;
    _consentedSessionId = null;
    _lastRequestAt = null;
    clearRecommendation();
  }

  void markRequestStarted(String sessionId) {
    if (_activeSessionId == sessionId) _lastRequestAt = DateTime.now();
  }

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

  void clearRecommendation() {
    _requestGeneration++;
    emit(const RideCoachState());
  }

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
