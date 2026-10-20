import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/authentication/data/biometric_sign_in_settings_repository.dart';
import 'package:senapath/features/authentication/data/cloud_account_gateway.dart';
import 'package:senapath/features/authentication/data/custom_auth_session_manager.dart';
import 'package:senapath/features/authentication/data/device_authenticator.dart';
import 'package:senapath/features/authentication/presentation/cloud_account_cubit.dart';

class FakeCloudAccountGateway implements CloudAccountGateway {
  FakeCloudAccountGateway({this.isConfigured = true});

  @override
  final bool isConfigured;

  final _authChanges = StreamController<String?>.broadcast();

  @override
  String? currentEmail;
  bool hasRememberedSessionValue = false;
  Object? registerError;
  Object? signInError;
  Object? signOutError;
  Object? restoreError;
  var restoreCalls = 0;
  var signOutCalls = 0;
  CloudAccountRegistrationResult registrationResult =
      const CloudAccountRegistrationResult(hasSession: true);

  @override
  Stream<String?> get authChanges => _authChanges.stream;

  @override
  Future<bool> get hasRememberedSession async => hasRememberedSessionValue;

  @override
  Future<CloudAccountRegistrationResult> register({
    required String email,
    required String password,
  }) async {
    final failure = registerError;
    if (failure != null) throw failure;
    currentEmail = email;
    _authChanges.add(email);
    return registrationResult;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final failure = signInError;
    if (failure != null) throw failure;
    currentEmail = email;
    _authChanges.add(email);
  }

  @override
  Future<void> restoreRememberedSession() async {
    restoreCalls++;
    final failure = restoreError;
    if (failure != null) throw failure;
    currentEmail ??= 'stored@example.com';
    _authChanges.add(currentEmail);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    final failure = signOutError;
    if (failure != null) throw failure;
    currentEmail = null;
    _authChanges.add(null);
  }

  Future<void> dispose() => _authChanges.close();

  void emitAuth(String? email) {
    currentEmail = email;
    _authChanges.add(email);
  }
}

class FakeDeviceAuthenticator implements DeviceAuthenticator {
  FakeDeviceAuthenticator({
    this.hasEnrolledBiometricsValue = true,
    this.authenticateResult = true,
  });

  final bool hasEnrolledBiometricsValue;

  @override
  Future<bool> get hasEnrolledBiometrics async => hasEnrolledBiometricsValue;

  @override
  Future<bool> get supportsDeviceCredentials async => true;

  bool authenticateResult;
  Object? authenticateError;
  int authenticateCalls = 0;

  @override
  Future<bool> authenticate({required bool biometricOnly}) async {
    authenticateCalls++;
    final failure = authenticateError;
    if (failure != null) throw failure;
    return authenticateResult;
  }
}

void main() {
  const validEmail = 'budi@example.com';
  const validPassword = 'katasandi123';

  group('CloudAccountCubit registration', () {
    test('validates input before calling the gateway', () async {
      final gateway = FakeCloudAccountGateway();
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      await cubit.register(email: 'bukan-email', password: validPassword);
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.isSignedIn, isFalse);

      await cubit.register(email: validEmail, password: 'abc');
      expect(cubit.state.error, isNotNull);
    });

    test('reports an unconfigured feature', () async {
      final gateway = FakeCloudAccountGateway(isConfigured: false);
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      await cubit.register(email: validEmail, password: validPassword);
      expect(cubit.state.error, 'Fitur akun online belum tersedia.');
    });

    test('signs the rider in when the session arrives', () async {
      final gateway = FakeCloudAccountGateway();
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      await cubit.register(email: '  $validEmail  ', password: validPassword);
      expect(cubit.state.isSignedIn, isTrue);
      expect(cubit.state.email, validEmail);
      expect(cubit.state.status, contains('sudah masuk'));
      expect(cubit.state.isLoading, isFalse);
    });

    test('stays signed out when confirmation is required', () async {
      final gateway = FakeCloudAccountGateway()
        ..registrationResult =
            const CloudAccountRegistrationResult(hasSession: false);
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      await cubit.register(email: validEmail, password: validPassword);
      expect(cubit.state.isSignedIn, isFalse);
      expect(cubit.state.status, 'Akun berhasil dibuat.');
    });

    test('surfaces CustomAuthException messages', () async {
      final gateway = FakeCloudAccountGateway()
        ..registerError = const CustomAuthException(
          status: 400,
          message: 'Email sudah terdaftar.',
        );
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      await cubit.register(email: validEmail, password: validPassword);
      expect(cubit.state.error, 'Email sudah terdaftar.');
    });

    test('falls back to a generic message for unknown errors', () async {
      final gateway = FakeCloudAccountGateway()..registerError = Exception('x');
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      await cubit.register(email: validEmail, password: validPassword);
      expect(cubit.state.error, contains('Pendaftaran gagal'));
    });
  });

  group('CloudAccountCubit.signIn', () {
    test('signs in and refreshes biometric availability', () async {
      final gateway = FakeCloudAccountGateway()
        ..hasRememberedSessionValue = true;
      final authenticator = FakeDeviceAuthenticator();
      final cubit = CloudAccountCubit(
        gateway,
        authenticator: authenticator,
      );
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      await cubit.signIn(email: validEmail, password: validPassword);
      expect(cubit.state.isSignedIn, isTrue);
      expect(cubit.state.status, contains('Berhasil masuk'));
      expect(cubit.state.canUseBiometrics, isTrue);
    });

    test('reports invalid credentials', () async {
      final gateway = FakeCloudAccountGateway()
        ..signInError = const CustomAuthException(
          status: 401,
          message: 'Email atau kata sandi salah.',
        );
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      await cubit.signIn(email: validEmail, password: validPassword);
      expect(cubit.state.error, 'Email atau kata sandi salah.');
      expect(cubit.state.isSignedIn, isFalse);
    });

    test('reports network failures', () async {
      final gateway = FakeCloudAccountGateway()..signInError = Exception('x');
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      await cubit.signIn(email: validEmail, password: validPassword);
      expect(cubit.state.error, contains('Tidak dapat masuk'));
    });
  });

  group('CloudAccountCubit.signOut', () {
    test('clears the session', () async {
      final gateway = FakeCloudAccountGateway();
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);
      await cubit.signIn(email: validEmail, password: validPassword);

      await cubit.signOut();
      expect(cubit.state.isSignedIn, isFalse);
      expect(cubit.state.canUseBiometrics, isFalse);
      expect(cubit.state.status, contains('Berhasil keluar'));
      expect(gateway.signOutCalls, 1);
    });

    test('reports sign-out failures', () async {
      final gateway = FakeCloudAccountGateway()
        ..signOutError = Exception('offline');
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);
      await cubit.signIn(email: validEmail, password: validPassword);

      await cubit.signOut();
      expect(cubit.state.error, contains('Keluar dari akun online gagal'));
      expect(cubit.state.isSignedIn, isTrue);
    });

    test('is a no-op when the feature is unconfigured', () async {
      final gateway = FakeCloudAccountGateway(isConfigured: false);
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      await cubit.signOut();
      expect(gateway.signOutCalls, 0);
      expect(cubit.state.status, isNull);
    });
  });

  group('CloudAccountCubit auth subscription', () {
    test('initialize marks the state ready and listens for changes', () async {
      final gateway = FakeCloudAccountGateway();
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      await cubit.initialize();
      expect(cubit.state.isInitialized, isTrue);
      expect(cubit.state.isInitializing, isFalse);

      gateway.emitAuth('baru@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.email, 'baru@example.com');

      gateway.emitAuth(null);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.isSignedIn, isFalse);
    });

    test('restores a remembered session when biometrics are off', () async {
      final gateway = FakeCloudAccountGateway()
        ..hasRememberedSessionValue = true;
      final cubit = CloudAccountCubit(
        gateway,
        biometricSettings: _FakeBiometricSettings(),
      );
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      await cubit.initialize();
      expect(gateway.restoreCalls, 1);
      expect(cubit.state.email, 'stored@example.com');
      expect(cubit.state.canUseBiometrics, isFalse, reason: 'no authenticator');
    });

    test('skips restore when biometrics are enabled and available', () async {
      final gateway = FakeCloudAccountGateway()
        ..hasRememberedSessionValue = true;
      final cubit = CloudAccountCubit(
        gateway,
        authenticator: FakeDeviceAuthenticator(),
        biometricSettings: _FakeBiometricSettings()..enabled = true,
      );
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      await cubit.initialize();
      expect(gateway.restoreCalls, 0);
      expect(cubit.state.canUseBiometrics, isTrue);
    });

    test('reports a broken remembered session', () async {
      final gateway = FakeCloudAccountGateway()
        ..hasRememberedSessionValue = true
        ..restoreError = StateError('Sesi kedaluwarsa.');
      final cubit = CloudAccountCubit(
        gateway,
        biometricSettings: _FakeBiometricSettings(),
      );
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      await cubit.initialize();
      expect(cubit.state.isInitialized, isTrue);
      expect(cubit.state.error, 'Sesi kedaluwarsa.');
    });

    test('initializes even when unconfigured', () async {
      final gateway = FakeCloudAccountGateway(isConfigured: false);
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      await cubit.initialize();
      expect(cubit.state.isInitialized, isTrue);
      expect(cubit.state.isConfigured, isFalse);
    });
  });

  group('CloudAccountCubit biometric sign-in', () {
    test('requires an available authenticator', () async {
      final cubit = CloudAccountCubit(FakeCloudAccountGateway());
      addTearDown(cubit.close);

      await cubit.signInWithBiometrics();
      expect(cubit.state.error, contains('belum tersedia'));
    });

    test('signs in through the device authenticator', () async {
      final gateway = FakeCloudAccountGateway()
        ..hasRememberedSessionValue = true;
      final authenticator = FakeDeviceAuthenticator();
      final cubit = CloudAccountCubit(gateway, authenticator: authenticator);
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);
      await cubit.initialize();

      await cubit.signInWithBiometrics();
      expect(authenticator.authenticateCalls, 1);
      expect(cubit.state.isSignedIn, isTrue);
      expect(cubit.state.status, contains('sidik jari atau wajah'));
    });

    test('handles a cancelled prompt', () async {
      final gateway = FakeCloudAccountGateway()
        ..hasRememberedSessionValue = true;
      final authenticator = FakeDeviceAuthenticator(authenticateResult: false);
      final cubit = CloudAccountCubit(gateway, authenticator: authenticator);
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);
      await cubit.initialize();

      await cubit.signInWithBiometrics();
      expect(cubit.state.error, contains('dibatalkan atau tidak berhasil'));
      expect(cubit.state.isSignedIn, isFalse);
    });

    test('handles authenticator failures', () async {
      final gateway = FakeCloudAccountGateway()
        ..hasRememberedSessionValue = true;
      final authenticator = FakeDeviceAuthenticator()
        ..authenticateError = StateError('Sensor rusak');
      final cubit = CloudAccountCubit(gateway, authenticator: authenticator);
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);
      await cubit.initialize();

      await cubit.signInWithBiometrics();
      expect(cubit.state.error, 'Sensor rusak');
    });
  });

  group('CloudAccountCubit.setBiometricSignInEnabled', () {
    test('requires sign-in before enabling', () async {
      final cubit = CloudAccountCubit(
        FakeCloudAccountGateway(),
        biometricSettings: _FakeBiometricSettings(),
      );
      addTearDown(cubit.close);

      await cubit.setBiometricSignInEnabled(true);
      expect(cubit.state.error, contains('Masuk terlebih dahulu'));
    });

    test('requires enrolled biometrics', () async {
      final gateway = FakeCloudAccountGateway();
      final cubit = CloudAccountCubit(
        gateway,
        authenticator: FakeDeviceAuthenticator(
          hasEnrolledBiometricsValue: false,
        ),
        biometricSettings: _FakeBiometricSettings(),
      );
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);
      await cubit.signIn(email: validEmail, password: validPassword);

      await cubit.setBiometricSignInEnabled(true);
      expect(cubit.state.error, contains('Siapkan sidik jari'));
    });

    test('requires a remembered session', () async {
      final gateway = FakeCloudAccountGateway();
      final cubit = CloudAccountCubit(
        gateway,
        authenticator: FakeDeviceAuthenticator(),
        biometricSettings: _FakeBiometricSettings(),
      );
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);
      await cubit.signIn(email: validEmail, password: validPassword);

      await cubit.setBiometricSignInEnabled(true);
      expect(cubit.state.error, contains('belum tersimpan di ponsel'));
    });

    test('saves the preference when enabling', () async {
      final gateway = FakeCloudAccountGateway()
        ..hasRememberedSessionValue = true;
      final settings = _FakeBiometricSettings();
      final cubit = CloudAccountCubit(
        gateway,
        authenticator: FakeDeviceAuthenticator(),
        biometricSettings: settings,
      );
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);
      await cubit.signIn(email: validEmail, password: validPassword);

      await cubit.setBiometricSignInEnabled(true);
      expect(settings.saved, [true]);
      expect(cubit.state.biometricSignInEnabled, isTrue);
      expect(cubit.state.status, contains('akan diminta'));
    });

    test('disabling does not need biometric checks', () async {
      final gateway = FakeCloudAccountGateway();
      final settings = _FakeBiometricSettings();
      final cubit = CloudAccountCubit(gateway, biometricSettings: settings);
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      await cubit.setBiometricSignInEnabled(false);
      expect(settings.saved, [false]);
      expect(cubit.state.biometricSignInEnabled, isFalse);
      expect(cubit.state.status, contains('dimatikan'));
    });

    test('reports a missing settings repository', () async {
      final gateway = FakeCloudAccountGateway();
      final cubit = CloudAccountCubit(gateway);
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      await cubit.setBiometricSignInEnabled(false);
      expect(cubit.state.error, contains('tidak dapat disimpan'));
    });

    test('reports save failures', () async {
      final gateway = FakeCloudAccountGateway();
      final cubit = CloudAccountCubit(
        gateway,
        biometricSettings: _FakeBiometricSettings()
          ..error = StateError('Penyimpanan penuh'),
      );
      addTearDown(cubit.close);
      addTearDown(gateway.dispose);

      await cubit.setBiometricSignInEnabled(false);
      expect(cubit.state.error, 'Penyimpanan penuh');
    });
  });
}

class _FakeBiometricSettings implements BiometricSignInSettingsRepository {
  bool enabled = false;
  final List<bool> saved = [];
  Object? error;

  @override
  Future<bool> load() async => enabled;

  @override
  Future<void> save(bool value) async {
    final failure = error;
    if (failure != null) throw failure;
    saved.add(value);
    enabled = value;
  }
}
