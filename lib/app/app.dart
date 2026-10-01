import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/units/unit_settings_cubit.dart';
import '../features/emergency/presentation/emergency_cubit.dart';
import '../features/authentication/presentation/device_auth_cubit.dart';
import '../features/profile/presentation/profile_cubit.dart';
import '../features/routes/presentation/routes_cubit.dart';
import '../features/session/presentation/session_cubit.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class SenapathApp extends StatelessWidget {
  const SenapathApp({
    required this.authCubit,
    required this.emergencyCubit,
    required this.profileCubit,
    required this.routesCubit,
    required this.unitSettingsCubit,
    required this.sessionCubit,
    super.key,
  });

  final DeviceAuthCubit authCubit;
  final EmergencyCubit emergencyCubit;
  final ProfileCubit profileCubit;
  final RoutesCubit routesCubit;
  final UnitSettingsCubit unitSettingsCubit;
  final RideSessionCubit sessionCubit;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: authCubit),
        BlocProvider.value(value: emergencyCubit),
        BlocProvider.value(value: profileCubit),
        BlocProvider.value(value: routesCubit),
        BlocProvider.value(value: unitSettingsCubit),
        BlocProvider.value(value: sessionCubit),
      ],
      child: MaterialApp.router(
        title: 'Senapath',
        theme: AppTheme.light,
        routerConfig: appRouter,
      ),
    );
  }
}
