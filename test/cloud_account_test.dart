import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/authentication/data/cloud_account_gateway.dart';
import 'package:senapath/features/authentication/presentation/cloud_account_cubit.dart';

void main() {
  test(
    'register uses Supabase and reports email verification requirement',
    () async {
      final gateway = _FakeCloudAccountGateway()
        ..registrationHasSession = false;
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);

      await cubit.register(
        email: '  rider@example.com ',
        password: 'strong-pass-1',
      );

      expect(gateway.registeredEmail, 'rider@example.com');
      expect(gateway.registeredPassword, 'strong-pass-1');
      expect(cubit.state.isSignedIn, isFalse);
      expect(cubit.state.status, contains('Periksa email'));
    },
  );

  test(
    'sign-in, password reset, and sign-out use cloud auth gateway',
    () async {
      final gateway = _FakeCloudAccountGateway();
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);

      await cubit.signIn(email: 'rider@example.com', password: 'strong-pass-1');
      expect(cubit.state.email, 'rider@example.com');

      await cubit.sendPasswordReset('rider@example.com');
      expect(gateway.resetEmail, 'rider@example.com');
      expect(cubit.state.status, contains('Jika email terdaftar'));

      await cubit.signOut();
      expect(gateway.signOutCalls, 1);
      expect(cubit.state.isSignedIn, isFalse);
      expect(cubit.state.status, contains('Data lokal tetap tersimpan'));
    },
  );

  test(
    'Google sign-in starts OAuth and waits for auth state confirmation',
    () async {
      final gateway = _FakeCloudAccountGateway();
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);

      await cubit.signInWithGoogle();

      expect(gateway.googleSignInCalls, 1);
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.isSignedIn, isFalse);
      expect(cubit.state.status, contains('Selesaikan login Google'));
    },
  );

  test('Google sign-in reports missing Supabase configuration', () async {
    final gateway = _FakeCloudAccountGateway(isConfigured: false);
    final cubit = CloudAccountCubit(gateway);
    addTearDown(cubit.close);

    await cubit.signInWithGoogle();

    expect(gateway.googleSignInCalls, 0);
    expect(cubit.state.error, contains('belum dikonfigurasi'));
  });

  test('Google sign-in reports browser launch failure', () async {
    final gateway = _FakeCloudAccountGateway()
      ..googleSignInLaunchResult = false;
    final cubit = CloudAccountCubit(gateway);
    addTearDown(cubit.close);

    await cubit.signInWithGoogle();

    expect(cubit.state.error, contains('Browser login Google'));
  });

  test('rejects invalid credentials before calling Supabase', () async {
    final gateway = _FakeCloudAccountGateway();
    final cubit = CloudAccountCubit(gateway);
    addTearDown(cubit.close);

    await cubit.register(email: 'not-an-email', password: 'short');

    expect(gateway.registeredEmail, isNull);
    expect(cubit.state.error, isNotNull);
  });

  test(
    'shows an honest unavailable state without Supabase configuration',
    () async {
      final gateway = _FakeCloudAccountGateway(isConfigured: false);
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);

      await cubit.signIn(email: 'rider@example.com', password: 'strong-pass-1');

      expect(gateway.signInCalls, 0);
      expect(cubit.state.error, contains('belum dikonfigurasi'));
    },
  );
}

class _FakeCloudAccountGateway implements CloudAccountGateway {
  _FakeCloudAccountGateway({this.isConfigured = true});

  @override
  final bool isConfigured;

  @override
  String? currentEmail;
  String? registeredEmail;
  String? registeredPassword;
  String? resetEmail;
  bool registrationHasSession = true;
  int signInCalls = 0;
  int googleSignInCalls = 0;
  int signOutCalls = 0;
  bool googleSignInLaunchResult = true;

  @override
  Stream<String?> get authChanges => const Stream.empty();

  @override
  Future<CloudAccountRegistrationResult> register({
    required String email,
    required String password,
  }) async {
    registeredEmail = email;
    registeredPassword = password;
    if (registrationHasSession) currentEmail = email;
    return CloudAccountRegistrationResult(hasSession: registrationHasSession);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    resetEmail = email;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    currentEmail = email;
  }

  @override
  Future<bool> signInWithGoogle() async {
    googleSignInCalls++;
    return googleSignInLaunchResult;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    currentEmail = null;
  }
}
