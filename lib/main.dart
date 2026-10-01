import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/storage/app_database.dart';
import 'core/storage/secure_vault.dart';
import 'core/units/unit_settings_cubit.dart';
import 'core/units/unit_settings_repository.dart';
import 'features/authentication/data/device_authenticator.dart';
import 'features/authentication/data/supabase_cloud_account_gateway.dart';
import 'features/authentication/presentation/device_auth_cubit.dart';
import 'features/authentication/presentation/cloud_account_cubit.dart';
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
import 'features/logistics/data/logistics_repository.dart';
import 'features/logistics/presentation/logistics_cubit.dart';
import 'features/reaction/data/reaction_test_repository.dart';
import 'features/reaction/presentation/reaction_test_cubit.dart';
import 'features/assistant/data/supabase_ai_chat_gateway.dart';
import 'features/assistant/presentation/ai_chat_cubit.dart';
import 'features/feedback/data/feedback_repository.dart';
import 'features/feedback/data/supabase_feedback_gateway.dart';
import 'features/feedback/presentation/feedback_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  SupabaseClient? supabaseClient;
  if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
    supabaseClient = Supabase.instance.client;
  }

  final secureVault = FlutterSecureVault();
  final database = AppDatabase();
  final telemetryCodec = EncryptedTelemetryCodec(secureVault: secureVault);
  final sessionRepository = DriftRideSessionRepository(
    database: database,
    telemetryCodec: telemetryCodec,
  );

  runApp(
    SenapathApp(
      authCubit: DeviceAuthCubit(LocalDeviceAuthenticator()),
      cloudAccountCubit: CloudAccountCubit(
        SupabaseCloudAccountGateway(supabaseClient),
      ),
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
        SavedRouteRepository(database, geometryCodec: telemetryCodec),
        const RouteFileExchange(SessionFileService()),
      ),
      unitSettingsCubit: UnitSettingsCubit(UnitSettingsRepository(database)),
      logisticsCubit: LogisticsCubit(LogisticsRepository(database)),
      reactionTestCubit: ReactionTestCubit(ReactionTestRepository(database)),
      aiChatCubit: AiChatCubit(SupabaseAiChatGateway(supabaseClient)),
      feedbackCubit: FeedbackCubit(
        FeedbackRepository(secureVault),
        SupabaseFeedbackGateway(supabaseClient),
      ),
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
