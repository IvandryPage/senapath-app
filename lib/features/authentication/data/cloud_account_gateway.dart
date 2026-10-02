class CloudAccountRegistrationResult {
  const CloudAccountRegistrationResult({required this.hasSession});

  final bool hasSession;
}

const googleOAuthRedirectUri = 'senapath://login-callback/';

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
  Future<void> signOut();
}
