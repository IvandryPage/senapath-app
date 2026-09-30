import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/app/app.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/core/units/unit_settings_cubit.dart';
import 'package:senapath/core/units/unit_settings_repository.dart';
import 'package:senapath/core/widgets/feature_state_view.dart';
import 'package:senapath/features/authentication/data/device_authenticator.dart';
import 'package:senapath/features/authentication/presentation/device_auth_cubit.dart';
import 'package:senapath/features/profile/data/user_profile_repository.dart';
import 'package:senapath/features/profile/domain/user_profile.dart';
import 'package:senapath/features/profile/presentation/profile_cubit.dart';
import 'package:drift/native.dart';

void main() {
  testWidgets('main shell navigates between core destinations', (tester) async {
    final authCubit = DeviceAuthCubit(_FakeDeviceAuthenticator());
    await authCubit.initialize();
    await authCubit.authenticateWithBiometrics();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final settingsCubit = UnitSettingsCubit(UnitSettingsRepository(database));
    await settingsCubit.load();
    final profileCubit = ProfileCubit(_FakeProfileRepository());
    await profileCubit.load();

    await tester.pumpWidget(
      SenapathApp(
        authCubit: authCubit,
        profileCubit: profileCubit,
        unitSettingsCubit: settingsCubit,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Belum ada sesi'), findsOneWidget);

    await tester.tap(find.text('Rute').last);
    await tester.pumpAndSettle();
    expect(find.text('Belum ada rute tersimpan'), findsOneWidget);

    await tester.tap(find.text('Sesi').last);
    await tester.pumpAndSettle();
    expect(find.text('Perekaman belum dimulai'), findsOneWidget);

    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.text('Kontak darurat'), findsOneWidget);

    await tester.tap(find.byTooltip('Keluar'));
    await tester.pumpAndSettle();
    expect(find.text('Buka Senapath'), findsOneWidget);

    await tester.tap(find.text('Gunakan PIN atau sandi perangkat'));
    await tester.pumpAndSettle();
    expect(find.text('Kontak darurat'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
    await authCubit.close();
    await profileCubit.close();
    await settingsCubit.close();
  });

  testWidgets('loading state is announced with progress', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FeatureStateView.loading(message: 'Memuat rute')),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Memuat rute'), findsOneWidget);
  });

  testWidgets('error state exposes retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeatureStateView.error(
            message: 'Koneksi tidak tersedia',
            onAction: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Koneksi tidak tersedia'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    expect(retried, isTrue);
  });
}

class _FakeDeviceAuthenticator implements DeviceAuthenticator {
  @override
  Future<bool> get hasEnrolledBiometrics async => true;

  @override
  Future<bool> get supportsDeviceCredentials async => true;

  @override
  Future<bool> authenticate({required bool biometricOnly}) async => true;
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
