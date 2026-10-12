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
import 'package:senapath/features/gamification/domain/rider_progress.dart';

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
        const UserProfile(
          displayName: '  Rina  ',
          riderStyle: RiderStyle.climber,
        ),
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
      expect(repository.profile.riderStyle, RiderStyle.climber);
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

    test(
      'synchronizes a saved name and cyclist type to the online account',
      () async {
        final repository = _FakeProfileRepository()..cloudSignedIn = true;
        final cubit = ProfileCubit(repository);
        await cubit.load();

        await cubit.saveProfile(
          const UserProfile(
            displayName: 'Rina',
            riderStyle: RiderStyle.sprinter,
          ),
        );

        expect(repository.cloudProfile?.displayName, 'Rina');
        expect(repository.cloudProfile?.riderStyle, RiderStyle.sprinter);
        expect(
          cubit.state.message,
          'Profil tersimpan dan tersinkron ke akun online.',
        );
        await cubit.close();
      },
    );

    test('loads the online profile as the account source of truth', () async {
      final repository = _FakeProfileRepository()
        ..cloudSignedIn = true
        ..cloudProfile = const UserProfile(
          displayName: 'Nama akun',
          riderStyle: RiderStyle.ace,
        );
      final cubit = ProfileCubit(repository);
      await cubit.load();

      expect(cubit.state.profile.displayName, 'Nama akun');
      expect(cubit.state.profile.riderStyle, RiderStyle.ace);
      expect(repository.profile.displayName, 'Nama akun');
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

class _FakeProfileRepository
    implements UserProfileRepository, CloudUserProfileRepository {
  UserProfile profile = const UserProfile();
  UserProfile? cloudProfile;
  bool cloudSignedIn = false;
  List<EmergencyContact> contacts = [];

  @override
  bool get isCloudSignedIn => cloudSignedIn;

  @override
  Future<UserProfile?> loadCloudProfile() async => cloudProfile;

  @override
  Future<void> saveCloudProfile(UserProfile profile) async {
    cloudProfile = profile;
  }

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
