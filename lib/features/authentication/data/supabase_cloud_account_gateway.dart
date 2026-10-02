import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_account_gateway.dart';

class SupabaseCloudAccountGateway implements CloudAccountGateway {
  const SupabaseCloudAccountGateway(this._client);

  final SupabaseClient? _client;

  @override
  bool get isConfigured => _client != null;

  @override
  String? get currentEmail => _client?.auth.currentUser?.email;

  @override
  Stream<String?> get authChanges =>
      _client?.auth.onAuthStateChange.map(
        (event) => event.session?.user.email,
      ) ??
      const Stream.empty();

  @override
  Future<CloudAccountRegistrationResult> register({
    required String email,
    required String password,
  }) async {
    final response = await _requiredClient.auth.signUp(
      email: email,
      password: password,
    );
    return CloudAccountRegistrationResult(hasSession: response.session != null);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _requiredClient.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<bool> signInWithGoogle() => _requiredClient.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: googleOAuthRedirectUri,
  );

  @override
  Future<void> sendPasswordReset(String email) async {
    await _requiredClient.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> signOut() => _requiredClient.auth.signOut();

  SupabaseClient get _requiredClient =>
      _client ?? (throw StateError('Supabase belum dikonfigurasi.'));
}
