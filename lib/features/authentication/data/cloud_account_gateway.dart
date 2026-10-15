class CloudAccountRegistrationResult {
  const CloudAccountRegistrationResult({required this.hasSession});

  final bool hasSession;
}

abstract interface class CloudAccountGateway {
  bool get isConfigured;
  String? get currentEmail;
  Stream<String?> get authChanges;
  Future<bool> get hasRememberedSession;

  Future<CloudAccountRegistrationResult> register({
    required String email,
    required String password,
  });

  Future<void> signIn({required String email, required String password});
  Future<void> restoreRememberedSession();
  Future<void> signOut();
}
