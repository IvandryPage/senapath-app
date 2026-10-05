import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/assistant/presentation/ai_chat_cubit.dart';
import '../features/authentication/presentation/cloud_account_cubit.dart';
import '../core/units/unit_settings_cubit.dart';
import '../features/session/presentation/session_cubit.dart';
import '../features/emergency/presentation/emergency_cubit.dart';
import '../features/authentication/presentation/device_auth_cubit.dart';
import '../features/profile/presentation/profile_cubit.dart';
import '../features/routes/presentation/routes_cubit.dart';
import '../features/logistics/presentation/logistics_cubit.dart';
import '../features/reaction/presentation/reaction_test_cubit.dart';
import '../features/feedback/presentation/feedback_cubit.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_settings_cubit.dart';

class SenapathApp extends StatelessWidget {
  const SenapathApp({
    required this.authCubit,
    required this.cloudAccountCubit,
    required this.themeSettingsCubit,
    required this.emergencyCubit,
    required this.profileCubit,
    required this.routesCubit,
    required this.unitSettingsCubit,
    required this.sessionCubit,
    required this.logisticsCubit,
    required this.reactionTestCubit,
    required this.aiChatCubit,
    required this.feedbackCubit,
    super.key,
  });

  final DeviceAuthCubit authCubit;
  final CloudAccountCubit cloudAccountCubit;
  final ThemeSettingsCubit themeSettingsCubit;
  final EmergencyCubit emergencyCubit;
  final ProfileCubit profileCubit;
  final RoutesCubit routesCubit;
  final UnitSettingsCubit unitSettingsCubit;
  final RideSessionCubit sessionCubit;
  final LogisticsCubit logisticsCubit;
  final ReactionTestCubit reactionTestCubit;
  final AiChatCubit aiChatCubit;
  final FeedbackCubit feedbackCubit;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: authCubit),
        BlocProvider.value(value: cloudAccountCubit),
        BlocProvider.value(value: themeSettingsCubit),
        BlocProvider.value(value: emergencyCubit),
        BlocProvider.value(value: profileCubit),
        BlocProvider.value(value: routesCubit),
        BlocProvider.value(value: unitSettingsCubit),
        BlocProvider.value(value: sessionCubit),
        BlocProvider.value(value: logisticsCubit),
        BlocProvider.value(value: reactionTestCubit),
        BlocProvider.value(value: aiChatCubit),
        BlocProvider.value(value: feedbackCubit),
      ],
      child: BlocListener<CloudAccountCubit, CloudAccountState>(
        listenWhen: (previous, current) =>
            previous.email != current.email && previous.email != null,
        listener: (context, state) {
          aiChatCubit.clearConversation();
          sessionCubit.cancelPendingSync();
        },
        child: BlocBuilder<ThemeSettingsCubit, ThemeSettingsState>(
          builder: (context, state) => MaterialApp.router(
            title: 'Senapath',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: state.themeMode,
            routerConfig: appRouter,
          ),
        ),
      ),
    );
  }
}
