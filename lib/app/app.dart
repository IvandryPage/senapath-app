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
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class SenapathApp extends StatelessWidget {
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
      ],
      child: BlocListener<CloudAccountCubit, CloudAccountState>(
        listenWhen: (previous, current) =>
            previous.email != current.email && previous.email != null,
        listener: (context, state) {
          aiChatCubit.clearConversation();
          sessionCubit.cancelPendingSync();
          leaderboardCubit.clearForAccountChange();
          cyclingTeamCubit.clearForAccountChange();
        },
        child: MaterialApp.router(
          title: 'Senapath',
          theme: AppTheme.light,
          themeMode: ThemeMode.light,
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
