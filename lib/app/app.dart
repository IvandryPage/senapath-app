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
import '../features/strategy_game/presentation/strategy_game_cubit.dart';
import '../features/feedback/presentation/feedback_cubit.dart';
import '../features/leaderboard/presentation/leaderboard_cubit.dart';
import '../features/progress/presentation/activity_goals_cubit.dart';
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
    required this.strategyGameCubit,
    required this.aiChatCubit,
    required this.feedbackCubit,
    required this.leaderboardCubit,
    required this.activityGoalsCubit,
    super.key,
  });

  final CloudAccountCubit cloudAccountCubit;
  final EmergencyCubit emergencyCubit;
  final ProfileCubit profileCubit;
  final RoutesCubit routesCubit;
  final UnitSettingsCubit unitSettingsCubit;
  final RideSessionCubit sessionCubit;
  final LogisticsCubit logisticsCubit;
  final StrategyGameCubit strategyGameCubit;
  final AiChatCubit aiChatCubit;
  final FeedbackCubit feedbackCubit;
  final LeaderboardCubit leaderboardCubit;
  final ActivityGoalsCubit activityGoalsCubit;

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
        BlocProvider.value(value: strategyGameCubit),
        BlocProvider.value(value: aiChatCubit),
        BlocProvider.value(value: feedbackCubit),
        BlocProvider.value(value: leaderboardCubit),
        BlocProvider.value(value: activityGoalsCubit),
      ],
      child: BlocListener<CloudAccountCubit, CloudAccountState>(
        listenWhen: (previous, current) =>
            previous.email != current.email && previous.email != null,
        listener: (context, state) {
          aiChatCubit.clearConversation();
          sessionCubit.cancelPendingSync();
          leaderboardCubit.clearForAccountChange();
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
