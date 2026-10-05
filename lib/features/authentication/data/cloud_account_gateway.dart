class CloudAccountRegistrationResult {
  const CloudAccountRegistrationResult({required this.hasSession});

  final bool hasSession;
}

abstract interface class CloudAccountGateway {
  bool get isConfigured;
  String? get currentEmail;
  Stream<String?> get authChanges;

  Future<CloudAccountRegistrationResult> register({
    required String email,
    required String password,
  });

  Future<void> signIn({required String email, required String password});
  Future<bool> signInWithGoogle();
  Future<void> sendPasswordReset(String email);
  Future<void> verifyEmail(String token);
  Future<void> completePasswordReset({
    required String token,
    required String password,
  });
  Future<void> signOut();
}
