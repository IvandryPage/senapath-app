import 'custom_auth_session_manager.dart';
import 'cloud_account_gateway.dart';

class SupabaseCloudAccountGateway implements CloudAccountGateway {
  const SupabaseCloudAccountGateway({required this._sessionManager});

  final CustomAuthSessionManager _sessionManager;

  @override
  bool get isConfigured => _sessionManager.isConfigured;

  @override
  String? get currentEmail => _sessionManager.currentEmail;

  @override
  Stream<String?> get authChanges => _sessionManager.authChanges;

  @override
  Future<bool> get hasRememberedSession => _sessionManager.hasStoredSession;

  @override
  Future<CloudAccountRegistrationResult> register({
    required String email,
    required String password,
  }) async {
    await _sessionManager.authenticate(
      'register',
      values: {'email': email, 'password': password},
    );
    return const CloudAccountRegistrationResult(hasSession: true);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _sessionManager.authenticate(
      'sign-in',
      values: {'email': email, 'password': password},
    );
  }

  @override
  Future<void> signInWithRememberedSession() =>
      _sessionManager.restoreForBiometricSignIn();

  @override
  Future<void> signOut() => _sessionManager.signOut();
}
