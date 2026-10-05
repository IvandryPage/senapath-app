import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/authentication/data/cloud_account_gateway.dart';
import 'package:senapath/features/authentication/presentation/cloud_account_cubit.dart';

void main() {
  late _FakeCloudAccountGateway gateway;
  late CloudAccountCubit cubit;

  setUp(() {
    gateway = _FakeCloudAccountGateway();
    cubit = CloudAccountCubit(gateway);
  });

  tearDown(() async {
    await cubit.close();
    await gateway.close();
  });

  test('rejects invalid credentials before calling the provider', () async {
    await cubit.signIn(email: 'not-an-email', password: 'short');

    expect(gateway.signInCalls, 0);
    expect(cubit.state.error, contains('email'));
  });

  test('uses a generic password-reset acknowledgement', () async {
    await cubit.sendPasswordReset(' person@example.com ');

    expect(gateway.resetEmail, 'person@example.com');
    expect(cubit.state.status, contains('Jika email terdaftar'));
    expect(cubit.state.status, isNot(contains('person@example.com')));
  });

  test(
    'sign-out clears online identity while preserving local app access',
    () async {
      gateway.email = 'person@example.com';
      final signedInCubit = CloudAccountCubit(gateway);
      addTearDown(signedInCubit.close);

      await signedInCubit.signOut();

      expect(signedInCubit.state.isSignedIn, isFalse);
      expect(signedInCubit.state.isConfigured, isTrue);
      expect(
        signedInCubit.state.status,
        contains('Data lokal tetap tersimpan'),
      );
    },
  );
}

class _FakeCloudAccountGateway implements CloudAccountGateway {
  final StreamController<String?> _authChanges =
      StreamController<String?>.broadcast();
  String? email;
  String? resetEmail;
  int signInCalls = 0;

  Future<void> close() => _authChanges.close();

  @override
  bool get isConfigured => true;

  @override
  String? get currentEmail => email;

  @override
  Stream<String?> get authChanges => _authChanges.stream;

  @override
  Future<CloudAccountRegistrationResult> register({
    required String email,
    required String password,
  }) async => const CloudAccountRegistrationResult(hasSession: true);

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    this.email = email;
  }

  @override
  Future<bool> signInWithGoogle() async => true;

  @override
  Future<void> sendPasswordReset(String email) async {
    resetEmail = email;
  }

  @override
  Future<void> signOut() async {
    email = null;
    _authChanges.add(null);
  }
}
