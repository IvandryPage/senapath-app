abstract interface class RideCoachGateway {
  bool get isConfigured;
  bool get isSignedIn;

  Future<String> diagnoseConfiguration();

  Future<String> recommend({
    required Map<String, Object?> rideContext,
    required bool consent,
  });
}
