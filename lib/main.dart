import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/storage/app_database.dart';
import 'core/storage/secure_vault.dart';
import 'core/units/unit_settings_cubit.dart';
import 'core/units/unit_settings_repository.dart';
import 'features/authentication/data/device_authenticator.dart';
import 'features/authentication/presentation/device_auth_cubit.dart';
import 'features/emergency/data/emergency_contact_actions.dart';
import 'features/emergency/presentation/emergency_cubit.dart';
import 'features/profile/data/encrypted_avatar_store.dart';
import 'features/profile/data/user_profile_repository.dart';
import 'features/profile/presentation/profile_cubit.dart';
import 'features/routes/data/saved_route_repository.dart';
import 'features/routes/data/route_file_exchange.dart';
import 'features/routes/presentation/routes_cubit.dart';
import 'features/session/data/session_file_service.dart';
import 'features/session/data/encrypted_telemetry_codec.dart';
import 'features/session/data/readiness_checker.dart';
import 'features/session/data/ride_session_repository.dart';
import 'features/session/presentation/session_cubit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final secureVault = FlutterSecureVault();
  final database = AppDatabase();
  final sessionRepository = DriftRideSessionRepository(
    database: database,
    telemetryCodec: EncryptedTelemetryCodec(secureVault: secureVault),
  );

  runApp(
    SenapathApp(
      authCubit: DeviceAuthCubit(LocalDeviceAuthenticator()),
      emergencyCubit: EmergencyCubit(
        const UrlLauncherEmergencyContactActions(),
      ),
      profileCubit: ProfileCubit(
        SecureUserProfileRepository(
          secureVault: secureVault,
          avatarStore: EncryptedAvatarStore(secureVault: secureVault),
        ),
      ),
      routesCubit: RoutesCubit(
        SavedRouteRepository(database),
        const RouteFileExchange(SessionFileService()),
      ),
      unitSettingsCubit: UnitSettingsCubit(UnitSettingsRepository(database)),
      sessionCubit: RideSessionCubit(
        repository: sessionRepository,
        readinessChecker: const DeviceReadinessChecker(),
        locationSource: const GeolocatorLocationSource(),
        barometerSource: const SensorsPlusBarometerSource(),
        motionSensorSource: const SensorsPlusMotionSensorSource(),
      ),
    ),
  );
}
