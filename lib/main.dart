import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/storage/app_database.dart';
import 'core/storage/secure_vault.dart';
import 'core/units/unit_settings_cubit.dart';
import 'core/units/unit_settings_repository.dart';
import 'features/authentication/data/device_authenticator.dart';
import 'features/authentication/data/biometric_sign_in_settings_repository.dart';
import 'features/authentication/data/custom_auth_session_manager.dart';
import 'features/authentication/data/supabase_cloud_account_gateway.dart';
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
import 'features/assistant/data/supabase_ai_chat_gateway.dart';
import 'features/assistant/presentation/ai_chat_cubit.dart';
import 'features/leaderboard/data/supabase_leaderboard_gateway.dart';
import 'features/leaderboard/presentation/leaderboard_cubit.dart';
import 'features/progress/data/activity_goals_repository.dart';
import 'features/progress/presentation/activity_goals_cubit.dart';
import 'features/teams/data/cycling_team_repository.dart';
import 'features/teams/presentation/cycling_team_cubit.dart';
import 'features/notifications/data/notification_settings_repository.dart';
import 'features/notifications/data/ride_notification_service.dart';
import 'features/notifications/presentation/notification_settings_cubit.dart';
import 'features/gamification/data/rider_profile_repository.dart';
import 'features/gamification/presentation/rider_gamification_cubit.dart';
import 'features/ledger/data/ride_ledger_repository.dart';
import 'features/ledger/data/ride_ledger_sync_gateway.dart';
import 'features/ledger/presentation/ride_ledger_cubit.dart';
import 'features/ride_coach/data/supabase_ride_coach_gateway.dart';
import 'features/ride_coach/presentation/ride_coach_cubit.dart';
import 'features/workouts/data/interval_workout_repository.dart';
import 'features/workouts/presentation/interval_workout_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var supabaseUrl = '';
  var supabasePublishableKey = '';
  try {
    await dotenv.load(fileName: 'assets/config/client.env');
    supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    supabasePublishableKey = dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '';
  } catch (_) {
    // Local-only features remain available when client config is absent.
  }
  SupabaseClient? supabaseClient;
  if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
    supabaseClient = Supabase.instance.client;
  }

  final secureVault = FlutterSecureVault();
  final authSessionManager = CustomAuthSessionManager(
    client: supabaseClient,
    secureVault: secureVault,
  );
  final database = AppDatabase();
  final notificationService = LocalRideNotificationService();
  final notificationSettingsRepository = NotificationSettingsRepository(
    database,
  );
  final intervalWorkoutRepository = IntervalWorkoutRepository(database);
  final intervalWorkoutCubit = IntervalWorkoutCubit(intervalWorkoutRepository);
  unawaited(intervalWorkoutCubit.load());
  final rideLedgerRepository = RideLedgerRepository(database);
  final telemetryCodec = EncryptedTelemetryCodec(secureVault: secureVault);
  final sessionRepository = DriftRideSessionRepository(
    database: database,
    telemetryCodec: telemetryCodec,
  );
  runApp(
    SenapathApp(
      cloudAccountCubit: CloudAccountCubit(
        SupabaseCloudAccountGateway(sessionManager: authSessionManager),
        authenticator: LocalDeviceAuthenticator(),
        biometricSettings: BiometricSignInSettingsRepository(database),
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
      aiChatCubit: AiChatCubit(
        SupabaseAiChatGateway(supabaseClient, authSessionManager),
      ),
      leaderboardCubit: LeaderboardCubit(
        SupabaseLeaderboardGateway(supabaseClient, authSessionManager),
      ),
      activityGoalsCubit: ActivityGoalsCubit(ActivityGoalsRepository(database)),
      cyclingTeamCubit: CyclingTeamCubit(
        SupabaseCyclingTeamRepository(supabaseClient, authSessionManager),
      ),
      notificationSettingsCubit: NotificationSettingsCubit(
        notificationSettingsRepository,
        notificationService,
      ),
      riderGamificationCubit: RiderGamificationCubit(
        RiderProfileRepository(
          database,
          cloudClient: supabaseClient,
          sessionManager: authSessionManager,
        ),
      ),
      rideLedgerCubit: RideLedgerCubit(
        rideLedgerRepository,
        syncGateway: SupabaseRideLedgerSyncGateway(
          supabaseClient,
          authSessionManager,
        ),
      ),
      rideCoachCubit: RideCoachCubit(
        SupabaseRideCoachGateway(supabaseClient, authSessionManager),
      ),
      intervalWorkoutCubit: intervalWorkoutCubit,
      sessionCubit: RideSessionCubit(
        repository: sessionRepository,
        readinessChecker: const DeviceReadinessChecker(),
        locationSource: const GeolocatorLocationSource(),
        barometerSource: const SensorsPlusBarometerSource(),
        motionSensorSource: const SensorsPlusMotionSensorSource(),
        notificationService: notificationService,
        notificationSettingsRepository: notificationSettingsRepository,
        ledgerRepository: rideLedgerRepository,
        intervalWorkoutRepository: intervalWorkoutRepository,
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
