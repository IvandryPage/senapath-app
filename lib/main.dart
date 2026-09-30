import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/storage/app_database.dart';
import 'core/storage/secure_vault.dart';
import 'core/units/unit_settings_cubit.dart';
import 'core/units/unit_settings_repository.dart';
import 'features/authentication/data/device_authenticator.dart';
import 'features/authentication/presentation/device_auth_cubit.dart';
import 'features/profile/data/encrypted_avatar_store.dart';
import 'features/profile/data/user_profile_repository.dart';
import 'features/profile/presentation/profile_cubit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final secureVault = FlutterSecureVault();
  final database = AppDatabase();

  runApp(
    SenapathApp(
      authCubit: DeviceAuthCubit(LocalDeviceAuthenticator()),
      profileCubit: ProfileCubit(
        SecureUserProfileRepository(
          secureVault: secureVault,
          avatarStore: EncryptedAvatarStore(secureVault: secureVault),
        ),
      ),
      unitSettingsCubit: UnitSettingsCubit(UnitSettingsRepository(database)),
    ),
  );
}
