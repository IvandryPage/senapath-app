abstract interface class RideCoachGateway {
  bool get isConfigured;

  Future<String> recommend({
    required Map<String, Object?> rideContext,
    required bool consent,
  });
}
