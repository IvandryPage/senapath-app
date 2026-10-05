import 'package:google_sign_in/google_sign_in.dart';

import 'custom_auth_session_manager.dart';
import 'cloud_account_gateway.dart';

class SupabaseCloudAccountGateway implements CloudAccountGateway {
  static Future<void>? _googleInitialization;

  const SupabaseCloudAccountGateway({
    required CustomAuthSessionManager sessionManager,
    required String googleServerClientId,
    required String googleIosClientId,
  }) : _sessionManager = sessionManager,
       _googleServerClientId = googleServerClientId,
       _googleIosClientId = googleIosClientId;

  final CustomAuthSessionManager _sessionManager;
  final String _googleServerClientId;
  final String _googleIosClientId;

  @override
  bool get isConfigured => _sessionManager.isConfigured;

  @override
  String? get currentEmail => _sessionManager.currentEmail;

  @override
  Stream<String?> get authChanges => _sessionManager.authChanges;

  @override
  Future<CloudAccountRegistrationResult> register({
    required String email,
    required String password,
  }) async {
    final response = await _sessionManager.authenticate('register', values: {
      'email': email,
      'password': password,
    });
    return CloudAccountRegistrationResult(
      hasSession: response['emailVerificationRequired'] != true,
    );
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _sessionManager.authenticate('sign-in', values: {
      'email': email,
      'password': password,
    });
  }

  @override
  Future<bool> signInWithGoogle() async {
    if (_googleServerClientId.isEmpty) {
      throw StateError('Google sign-in belum dikonfigurasi di aplikasi.');
    }
    final google = GoogleSignIn.instance;
    try {
      await (_googleInitialization ??= google.initialize(
        serverClientId: _googleServerClientId,
        clientId: _googleIosClientId.isEmpty ? null : _googleIosClientId,
      ));
    } catch (_) {
      _googleInitialization = null;
      rethrow;
    }
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google tidak memberikan ID token yang dapat diverifikasi.');
    }
    await _sessionManager.authenticate('google', values: {'idToken': idToken});
    return true;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _sessionManager.authenticate(
      'password-reset-request',
      values: {'email': email},
    );
  }

  @override
  Future<void> verifyEmail(String token) async {
    await _sessionManager.authenticate('verify-email', values: {'token': token});
  }

  @override
  Future<void> completePasswordReset({
    required String token,
    required String password,
  }) async {
    await _sessionManager.authenticate(
      'password-reset-complete',
      values: {'token': token, 'password': password},
    );
  }

  @override
  Future<void> signOut() => _sessionManager.signOut();
}
