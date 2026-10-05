import '../domain/ride_session.dart';

abstract interface class SessionSyncGateway {
  bool get isConfigured;
  bool get isSignedIn;

  Future<void> uploadSummary(RideSessionSummary summary);
}

