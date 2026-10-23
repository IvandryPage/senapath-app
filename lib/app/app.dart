import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/assistant/presentation/ai_chat_cubit.dart';
import '../features/authentication/presentation/cloud_account_cubit.dart';
import '../core/units/unit_settings_cubit.dart';
import '../features/session/presentation/session_cubit.dart';
import '../features/emergency/presentation/emergency_cubit.dart';
import '../features/profile/presentation/profile_cubit.dart';
import '../features/routes/presentation/routes_cubit.dart';
import '../features/logistics/presentation/logistics_cubit.dart';
import '../features/leaderboard/presentation/leaderboard_cubit.dart';
import '../features/progress/presentation/activity_goals_cubit.dart';
import '../features/teams/presentation/cycling_team_cubit.dart';
import '../features/notifications/presentation/notification_settings_cubit.dart';
import '../features/gamification/presentation/rider_gamification_cubit.dart';
import '../features/ledger/presentation/ride_ledger_cubit.dart';
import '../features/ride_coach/presentation/ride_coach_cubit.dart';
import '../features/workouts/presentation/interval_workout_cubit.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class SenapathApp extends StatelessWidget {
  /// Membuat root widget dengan seluruh cubit yang dibagikan ke pohon widget.
  const SenapathApp({
    required this.cloudAccountCubit,
    required this.emergencyCubit,
    required this.profileCubit,
    required this.routesCubit,
    required this.unitSettingsCubit,
    required this.sessionCubit,
    required this.logisticsCubit,
    required this.aiChatCubit,
    required this.leaderboardCubit,
    required this.activityGoalsCubit,
    required this.cyclingTeamCubit,
    required this.notificationSettingsCubit,
    required this.riderGamificationCubit,
    required this.rideLedgerCubit,
    required this.rideCoachCubit,
    required this.intervalWorkoutCubit,
    super.key,
  });

  final CloudAccountCubit cloudAccountCubit;
  final EmergencyCubit emergencyCubit;
  final ProfileCubit profileCubit;
  final RoutesCubit routesCubit;
  final UnitSettingsCubit unitSettingsCubit;
  final RideSessionCubit sessionCubit;
  final LogisticsCubit logisticsCubit;
  final AiChatCubit aiChatCubit;
  final LeaderboardCubit leaderboardCubit;
  final ActivityGoalsCubit activityGoalsCubit;
  final CyclingTeamCubit cyclingTeamCubit;
  final NotificationSettingsCubit notificationSettingsCubit;
  final RiderGamificationCubit riderGamificationCubit;
  final RideLedgerCubit rideLedgerCubit;
  final RideCoachCubit rideCoachCubit;
  final IntervalWorkoutCubit intervalWorkoutCubit;

  /// Menyediakan cubit aplikasi, menyinkronkan data saat akun berubah, lalu
  /// menampilkan MaterialApp dengan tema yang mengikuti cahaya sekitar.
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: cloudAccountCubit),
        BlocProvider.value(value: emergencyCubit),
        BlocProvider.value(value: profileCubit),
        BlocProvider.value(value: routesCubit),
        BlocProvider.value(value: unitSettingsCubit),
        BlocProvider.value(value: sessionCubit),
        BlocProvider.value(value: logisticsCubit),
        BlocProvider.value(value: aiChatCubit),
        BlocProvider.value(value: leaderboardCubit),
        BlocProvider.value(value: activityGoalsCubit),
        BlocProvider.value(value: cyclingTeamCubit),
        BlocProvider.value(value: notificationSettingsCubit),
        BlocProvider.value(value: riderGamificationCubit),
        BlocProvider.value(value: rideLedgerCubit),
        BlocProvider.value(value: rideCoachCubit),
        BlocProvider.value(value: intervalWorkoutCubit),
      ],
      child: BlocListener<CloudAccountCubit, CloudAccountState>(
        listenWhen: (previous, current) => previous.email != current.email,
        listener: (context, state) async {
          aiChatCubit.clearConversation();
          sessionCubit.cancelPendingSync();
          leaderboardCubit.clearForAccountChange();
          cyclingTeamCubit.clearForAccountChange();
          riderGamificationCubit.clearForAccountChange();
          
          // Clear unsynced sessions when signing out to prevent data leakage
          if (!state.isSignedIn && state.email != null) {
            unawaited(sessionCubit.clearUnsyncedSessions());
          }
          
          unawaited(profileCubit.reloadProfile());
          if (state.isSignedIn) {
            unawaited(leaderboardCubit.load());
            // Pull cloud data immediately after sign-in, regardless of autoSyncEnabled setting
            unawaited(
              sessionCubit.initialize().then((_) async {
                // This will restore all cloud sessions to local device
                await sessionCubit.syncCloudSessions();
                // Update gamification with restored sessions
                await riderGamificationCubit.load(
                  sessionCubit.state.completedSessions,
                );
                // Push any local-only sessions if auto-sync is enabled
                await sessionCubit.syncPendingSessions();
              }),
            );
          }
        },
        child: BlocListener<RideSessionCubit, RideSessionState>(
          listenWhen: (previous, current) =>
              !identical(previous.completedSessions, current.completedSessions),
          listener: (context, state) =>
              leaderboardCubit.updateLocalRecords(state.completedSessions),
          child: BlocBuilder<RideSessionCubit, RideSessionState>(
            builder: (context, sessionState) {
              final ambient = sessionState.isAmbientBright;
              return MaterialApp.router(
                title: 'Senapath',
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: ambient == null
                    ? ThemeMode.system
                    : ambient
                    ? ThemeMode.light
                    : ThemeMode.dark,
                routerConfig: appRouter,
              );
            },
          ),
        ),
      ),
    );
  }
}
