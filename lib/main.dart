import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/theme/theme_settings_cubit.dart';
import 'app/theme/theme_settings_repository.dart';
import 'core/storage/app_database.dart';
import 'core/storage/secure_vault.dart';
import 'core/units/unit_settings_cubit.dart';
import 'core/units/unit_settings_repository.dart';
import 'features/authentication/data/device_authenticator.dart';
import 'features/authentication/data/custom_auth_session_manager.dart';
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
import 'features/session/data/session_sync_coordinator.dart';
import 'features/session/data/supabase_session_sync_gateway.dart';
import 'features/session/presentation/session_cubit.dart';
import 'features/logistics/data/logistics_repository.dart';
import 'features/logistics/presentation/logistics_cubit.dart';
import 'features/strategy_game/data/strategy_game_repository.dart';
import 'features/strategy_game/presentation/strategy_game_cubit.dart';
import 'features/assistant/data/supabase_ai_chat_gateway.dart';
import 'features/assistant/presentation/ai_chat_cubit.dart';
import 'features/feedback/data/feedback_repository.dart';
import 'features/feedback/data/supabase_feedback_gateway.dart';
import 'features/feedback/presentation/feedback_cubit.dart';
import 'features/leaderboard/data/supabase_leaderboard_gateway.dart';
import 'features/leaderboard/presentation/leaderboard_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var supabaseUrl = '';
  var supabasePublishableKey = '';
  var googleServerClientId = '';
  var googleIosClientId = '';
  try {
    await dotenv.load(fileName: 'assets/config/client.env');
    supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    supabasePublishableKey = dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '';
    googleServerClientId = dotenv.env['GOOGLE_SERVER_CLIENT_ID'] ?? '';
    googleIosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '';
  } catch (_) {
    // Local-only features remain available when client config is absent.
  }
  SupabaseClient? supabaseClient;
  if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabasePublishableKey,
      publishableKey: supabasePublishableKey,
    );
    supabaseClient = Supabase.instance.client;
  }

  final secureVault = FlutterSecureVault();
  final authSessionManager = CustomAuthSessionManager(
    client: supabaseClient,
    secureVault: secureVault,
  );
  await authSessionManager.restore();
  final database = AppDatabase();
  final telemetryCodec = EncryptedTelemetryCodec(secureVault: secureVault);
  final sessionRepository = DriftRideSessionRepository(
    database: database,
    telemetryCodec: telemetryCodec,
  );
  final themeSettingsCubit = ThemeSettingsCubit(
    ThemeSettingsRepository(database),
  );
  await themeSettingsCubit.load();

  runApp(
    SenapathApp(
      authCubit: DeviceAuthCubit(LocalDeviceAuthenticator()),
      cloudAccountCubit: CloudAccountCubit(
        SupabaseCloudAccountGateway(
          sessionManager: authSessionManager,
          googleServerClientId: googleServerClientId,
          googleIosClientId: googleIosClientId,
        ),
      ),
      themeSettingsCubit: themeSettingsCubit,
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
      strategyGameCubit: StrategyGameCubit(
        StrategyGameRepository(database),
      ),
      aiChatCubit: AiChatCubit(
        SupabaseAiChatGateway(supabaseClient, authSessionManager),
      ),
      feedbackCubit: FeedbackCubit(
        FeedbackRepository(secureVault),
        SupabaseFeedbackGateway(supabaseClient, authSessionManager),
      ),
      leaderboardCubit: LeaderboardCubit(
        SupabaseLeaderboardGateway(supabaseClient, authSessionManager),
      ),
      sessionCubit: RideSessionCubit(
        repository: sessionRepository,
        readinessChecker: const DeviceReadinessChecker(),
        locationSource: const GeolocatorLocationSource(),
        barometerSource: const SensorsPlusBarometerSource(),
        motionSensorSource: const SensorsPlusMotionSensorSource(),
        syncCoordinator: SessionSyncCoordinator(
          repository: sessionRepository,
          gateway: SupabaseSessionSyncGateway(
            supabaseClient,
            authSessionManager,
          ),
        ),
      ),
    ),
  );
}
