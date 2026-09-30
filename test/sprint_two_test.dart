import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/core/units/unit_settings_repository.dart';
import 'package:senapath/core/units/unit_system.dart';
import 'package:senapath/features/authentication/data/device_authenticator.dart';
import 'package:senapath/features/authentication/presentation/device_auth_cubit.dart';
import 'package:senapath/features/profile/data/user_profile_repository.dart';
import 'package:senapath/features/profile/domain/user_profile.dart';
import 'package:senapath/features/profile/presentation/profile_cubit.dart';

void main() {
  group('DeviceAuthCubit', () {
    test('rejected biometric authentication never unlocks the app', () async {
      final authenticator = _FakeDeviceAuthenticator(result: false);
      final cubit = DeviceAuthCubit(authenticator);
      await cubit.initialize();

      await cubit.authenticateWithBiometrics();

      expect(cubit.state.isUnlocked, isFalse);
      expect(cubit.state.message, isNotNull);
      await cubit.close();
    });

    test('device credential fallback unlocks and logout locks again', () async {
      final authenticator = _FakeDeviceAuthenticator(result: true);
      final cubit = DeviceAuthCubit(authenticator);
      await cubit.initialize();

      await cubit.authenticateWithDeviceCredentials();
      expect(authenticator.biometricOnlyCalls, [false]);
      expect(cubit.state.isUnlocked, isTrue);

      cubit.logout();
      expect(cubit.state.isUnlocked, isFalse);
      await cubit.close();
    });
  });

  group('ProfileCubit', () {
    test('stores profile and rejects a fourth emergency contact', () async {
      final repository = _FakeProfileRepository();
      final cubit = ProfileCubit(repository);
      await cubit.load();
      await cubit.saveProfile(
        const UserProfile(displayName: '  Rina  ', teamName: '  Senapath  '),
      );

      for (var index = 0; index < 3; index++) {
        await cubit.saveContact(
          EmergencyContact(
            id: 'contact-$index',
            name: 'Contact $index',
            phone: '+62812345678$index',
            relationship: 'Teman',
          ),
        );
      }
      await cubit.saveContact(
        const EmergencyContact(
          id: 'contact-4',
          name: 'Contact 4',
          phone: '+628123456789',
          relationship: 'Keluarga',
        ),
      );

      expect(repository.profile.displayName, 'Rina');
      expect(repository.profile.teamName, 'Senapath');
      expect(cubit.state.contacts, hasLength(3));
      expect(cubit.state.message, 'Maksimal tiga kontak darurat.');
      await cubit.close();
    });

    test('rejects a blank profile name', () async {
      final cubit = ProfileCubit(_FakeProfileRepository());
      await cubit.load();

      await cubit.saveProfile(const UserProfile(displayName: '  '));

      expect(cubit.state.profile.displayName, isEmpty);
      expect(cubit.state.message, 'Nama tidak boleh kosong.');
      await cubit.close();
    });
  });

  test('unit system persists through Drift preferences', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = UnitSettingsRepository(database);

    expect(await repository.load(), UnitSystem.metric);
    await repository.save(UnitSystem.imperial);
    expect(await repository.load(), UnitSystem.imperial);

    await database.close();
  });
}

class _FakeDeviceAuthenticator implements DeviceAuthenticator {
  _FakeDeviceAuthenticator({required this.result});

  final bool result;
  final List<bool> biometricOnlyCalls = [];

  @override
  Future<bool> get hasEnrolledBiometrics async => true;

  @override
  Future<bool> get supportsDeviceCredentials async => true;

  @override
  Future<bool> authenticate({required bool biometricOnly}) async {
    biometricOnlyCalls.add(biometricOnly);
    return result;
  }
}

class _FakeProfileRepository implements UserProfileRepository {
  UserProfile profile = const UserProfile();
  List<EmergencyContact> contacts = [];

  @override
  Future<List<EmergencyContact>> loadContacts() async => contacts;

  @override
  Future<Uint8List?> loadAvatar() async => null;

  @override
  Future<UserProfile> loadProfile() async => profile;

  @override
  Future<void> saveAvatar(Uint8List imageBytes) async {}

  @override
  Future<void> saveContacts(List<EmergencyContact> value) async {
    contacts = value;
  }

  @override
  Future<void> saveProfile(UserProfile value) async {
    profile = value;
  }
}
