import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/features/authentication/data/biometric_sign_in_settings_repository.dart';
import 'package:senapath/features/authentication/data/cloud_account_gateway.dart';
import 'package:senapath/features/authentication/data/custom_auth_session_manager.dart';
import 'package:senapath/features/authentication/data/device_authenticator.dart';
import 'package:senapath/features/authentication/presentation/cloud_account_cubit.dart';

void main() {
  test(
    'registration creates the account and signs in without email verification',
    () async {
      final gateway = _FakeCloudAccountGateway();
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);

      await cubit.register(
        email: '  rider@example.com ',
        password: 'strong-pass-1',
      );

      expect(gateway.registeredEmail, 'rider@example.com');
      expect(gateway.registeredPassword, 'strong-pass-1');
      expect(cubit.state.isSignedIn, isTrue);
      expect(cubit.state.status, contains('sudah masuk'));
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

  test('shows the server configuration error returned by app-auth', () async {
    final gateway = _FakeCloudAccountGateway()
      ..signInError = const CustomAuthException(
        status: 503,
        message: 'Auth server is missing APP_AUTH_JWT_SECRET. Configure Supabase Edge Function secrets.',
      );
    final cubit = CloudAccountCubit(gateway);
    addTearDown(cubit.close);

    await cubit.signIn(email: 'rider@example.com', password: 'strong-pass-1');

    expect(cubit.state.error, contains('APP_AUTH_JWT_SECRET'));
  });

  test('rejects invalid credentials before calling Supabase', () async {
    final gateway = _FakeCloudAccountGateway();
    final cubit = CloudAccountCubit(gateway);
    addTearDown(cubit.close);

    await cubit.register(email: 'not-an-email', password: 'short');

    expect(gateway.registeredEmail, isNull);
    expect(cubit.state.error, isNotNull);
  });

  test('biometric sign-in restores the remembered online account', () async {
    final gateway = _FakeCloudAccountGateway()
      ..rememberedSession = true
      ..rememberedEmail = 'rider@example.com';
    final authenticator = _FakeAuthenticator();
    final cubit = CloudAccountCubit(gateway, authenticator: authenticator);
    addTearDown(cubit.close);

    cubit.initialize();
    await Future<void>.delayed(Duration.zero);
    await cubit.signInWithBiometrics();

    expect(authenticator.calls, 1);
    expect(gateway.restoreCalls, 1);
    expect(cubit.state.isSignedIn, isTrue);
    expect(cubit.state.email, 'rider@example.com');
    expect(cubit.state.status, contains('biometrik'));
  });

  test(
    'startup requires enabled biometrics for a remembered session',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final settings = BiometricSignInSettingsRepository(database);
      await settings.save(true);
      final gateway = _FakeCloudAccountGateway()
        ..rememberedSession = true
        ..rememberedEmail = 'rider@example.com';
      final cubit = CloudAccountCubit(
        gateway,
        authenticator: _FakeAuthenticator(),
        biometricSettings: settings,
      );
      addTearDown(cubit.close);

      await cubit.initialize();

      expect(cubit.state.isInitialized, isTrue);
      expect(cubit.state.isSignedIn, isFalse);
      expect(cubit.state.biometricSignInEnabled, isTrue);
      expect(cubit.state.canUseBiometrics, isTrue);
      expect(gateway.restoreCalls, 0);
    },
  );

  test(
    'startup restores a remembered session when biometrics are off',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final settings = BiometricSignInSettingsRepository(database);
      final gateway = _FakeCloudAccountGateway()
        ..rememberedSession = true
        ..rememberedEmail = 'rider@example.com';
      final cubit = CloudAccountCubit(
        gateway,
        authenticator: _FakeAuthenticator(),
        biometricSettings: settings,
      );
      addTearDown(cubit.close);

      await cubit.initialize();

      expect(cubit.state.isSignedIn, isTrue);
      expect(cubit.state.email, 'rider@example.com');
      expect(cubit.state.biometricSignInEnabled, isFalse);
      expect(gateway.restoreCalls, 1);
    },
  );

  test(
    'biometric sign-in preference is persisted and can be disabled',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final settings = BiometricSignInSettingsRepository(database);
      final gateway = _FakeCloudAccountGateway();
      final cubit = CloudAccountCubit(
        gateway,
        authenticator: _FakeAuthenticator(),
        biometricSettings: settings,
      );
      addTearDown(cubit.close);

      await cubit.signIn(email: 'rider@example.com', password: 'strong-pass-1');
      await cubit.setBiometricSignInEnabled(true);
      expect(cubit.state.biometricSignInEnabled, isTrue);
      expect(await settings.load(), isTrue);

      await cubit.setBiometricSignInEnabled(false);
      expect(cubit.state.biometricSignInEnabled, isFalse);
      expect(await settings.load(), isFalse);
    },
  );

  test(
    'repeated manual submissions are ignored while sign-in is pending',
    () async {
      final gateway = _FakeCloudAccountGateway()
        ..signInCompleter = Completer<void>();
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);

      final firstAttempt = cubit.signIn(
        email: 'rider@example.com',
        password: 'strong-pass-1',
      );
      await Future<void>.delayed(Duration.zero);
      await cubit.signIn(email: 'rider@example.com', password: 'strong-pass-1');

      expect(gateway.signInCalls, 1);
      gateway.signInCompleter!.complete();
      await firstAttempt;
      expect(cubit.state.isSignedIn, isTrue);
    },
  );

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
  String? rememberedEmail;
  bool rememberedSession = false;
  bool registrationHasSession = true;
  int signInCalls = 0;
  int restoreCalls = 0;
  int signOutCalls = 0;
  Object? signInError;
  Completer<void>? signInCompleter;

  @override
  Stream<String?> get authChanges => const Stream.empty();

  @override
  Future<bool> get hasRememberedSession async => rememberedSession;

  @override
  Future<CloudAccountRegistrationResult> register({
    required String email,
    required String password,
  }) async {
    registeredEmail = email;
    registeredPassword = password;
    if (registrationHasSession) {
      currentEmail = email;
      rememberedSession = true;
      rememberedEmail = email;
    }
    return CloudAccountRegistrationResult(hasSession: registrationHasSession);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    resetEmail = email;
  }

  @override
  Future<void> completePasswordReset({
    required String token,
    required String password,
  }) async {}

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    await signInCompleter?.future;
    if (signInError != null) throw signInError!;
    currentEmail = email;
    rememberedSession = true;
    rememberedEmail = email;
  }

  @override
  Future<void> signInWithRememberedSession() async {
    restoreCalls++;
    currentEmail = rememberedEmail;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    currentEmail = null;
    rememberedSession = false;
  }
}

class _FakeAuthenticator implements DeviceAuthenticator {
  int calls = 0;

  @override
  Future<bool> get hasEnrolledBiometrics async => true;

  @override
  Future<bool> get supportsDeviceCredentials async => true;

  @override
  Future<bool> authenticate({required bool biometricOnly}) async {
    calls++;
    return biometricOnly;
  }
}
