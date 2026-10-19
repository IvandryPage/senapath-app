import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/active_navigation_branch.dart';
import '../../features/overview/presentation/overview_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/profile_settings_screen.dart';
import '../../features/routes/presentation/routes_screen.dart';
import '../../features/session/presentation/session_cubit.dart';
import '../../features/session/presentation/session_screen.dart';
import '../../features/ride_coach/presentation/ride_coach_cubit.dart';
import '../../features/routes/data/pre_ride_weather_service.dart';
import '../../features/logistics/presentation/logistics_screen.dart';
import '../../features/authentication/presentation/cloud_account_screen.dart';
import '../../features/authentication/presentation/cloud_account_cubit.dart';
import '../../features/assistant/presentation/ai_chat_screen.dart';
import '../../features/feedback/presentation/feedback_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/progress/presentation/activity_progress_screen.dart';
import '../../features/teams/presentation/cycling_team_screen.dart';
import '../../features/notifications/presentation/notification_settings_screen.dart';
import '../../features/gamification/presentation/mini_game_screen.dart';
import '../../features/gamification/presentation/rider_screen.dart';
import '../../features/ledger/presentation/ride_ledger_screen.dart';
import '../../features/workouts/presentation/interval_workout_screen.dart';

const _destinations = <({String label, IconData icon, IconData selectedIcon})>[
  (label: 'Beranda', icon: Icons.home_outlined, selectedIcon: Icons.home),
  (label: 'Jelajah', icon: Icons.map_outlined, selectedIcon: Icons.map),
  (
    label: 'Logistik',
    icon: Icons.currency_exchange_outlined,
    selectedIcon: Icons.currency_exchange,
  ),
  (label: 'Profil', icon: Icons.person_outline, selectedIcon: Icons.person),
];

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/session', redirect: (context, state) => '/routes'),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _AppShell(navigationShell: navigationShell, location: state.uri.path),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const OverviewScreen(),
              routes: [
                GoRoute(
                  path: 'assistant',
                  builder: (context, state) => const AiChatScreen(),
                ),
                GoRoute(
                  path: 'feedback',
                  builder: (context, state) => const FeedbackScreen(),
                ),
                GoRoute(
                  path: 'leaderboard',
                  builder: (context, state) => const LeaderboardScreen(),
                ),
                GoRoute(
                  path: 'progress',
                  builder: (context, state) => const ActivityProgressScreen(),
                ),
                GoRoute(
                  path: 'account',
                  builder: (context, state) => const CloudAccountScreen(),
                ),
                GoRoute(
                  path: 'rider',
                  builder: (context, state) => const RiderScreen(),
                  routes: [
                    GoRoute(
                      path: 'ledger',
                      builder: (context, state) => const RideLedgerScreen(),
                    ),
                    GoRoute(
                      path: 'minigames',
                      builder: (context, state) => const MiniGameScreen(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/routes',
              builder: (context, state) => RoutesScreen(
                rideCoachCubit: context.read<RideCoachCubit>(),
                preRideWeatherService: OpenMeteoPreRideWeatherService(),
              ),
              routes: [
                GoRoute(
                  path: 'workouts',
                  builder: (context, state) => const IntervalWorkoutScreen(),
                ),
                GoRoute(
                  path: 'saved',
                  builder: (context, state) => SavedRoutesScreen(
                    rideCoachCubit: context.read<RideCoachCubit>(),
                    preRideWeatherService: OpenMeteoPreRideWeatherService(),
                    rideHistoryRepository: context
                        .read<RideSessionCubit>()
                        .rideHistoryRepository,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/logistics',
              builder: (context, state) => const LogisticsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'sessions',
                  builder: (context, state) =>
                      const SessionScreen(showMap: false, historyOnly: true),
                  routes: [
                    GoRoute(
                      path: ':sessionId',
                      builder: (context, state) => SessionScreen(
                        showMap: false,
                        historyOnly: true,
                        summarySessionId: state.pathParameters['sessionId'],
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'routes',
                  redirect: (context, state) => '/routes/saved',
                ),
                GoRoute(
                  path: 'settings',
                  builder: (context, state) => const ProfileSettingsScreen(),
                ),
                GoRoute(
                  path: 'notifications',
                  builder: (context, state) =>
                      const NotificationSettingsScreen(),
                ),
                GoRoute(
                  path: 'teams',
                  builder: (context, state) => const CyclingTeamScreen(),
                  routes: [
                    GoRoute(
                      path: ':teamId',
                      builder: (context, state) => CyclingTeamDashboardScreen(
                        teamId: state.pathParameters['teamId']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class _AppShell extends StatefulWidget {
  const _AppShell({required this.navigationShell, required this.location});

  final StatefulNavigationShell navigationShell;
  final String location;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<CloudAccountCubit>().initialize());
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<CloudAccountCubit>().state;
    if (account.isConfigured && !account.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (account.isConfigured && !account.isSignedIn) {
      return const Scaffold(body: CloudAccountScreen(isEntryFlow: true));
    }

    final title = switch (widget.location) {
      '/' => 'Senapath',
      '/assistant' => 'Asisten AI',
      '/feedback' => 'Saran dan kesan',
      '/leaderboard' => 'Papan Peringkat',
      '/progress' => 'Progres perjalanan',
      '/account' => 'Akun & keamanan',
      '/profile/settings' => 'Pengaturan',
      '/profile/notifications' => 'Notifikasi',
      '/rider' => 'Profil pesepeda',
      '/rider/ledger' => 'Bukti perjalanan',
      '/rider/minigames' => 'Mini games',
      '/profile/teams' => 'Tim',
      _ when widget.location.startsWith('/profile/teams/') => 'Detail tim',
      '/profile/sessions' => 'Riwayat perjalanan',
      _ when widget.location.startsWith('/profile/sessions/') =>
        'Detail perjalanan',
      '/routes/saved' => 'Pilih rute',
      '/routes/workouts' => 'Latihan interval',
      _ => _destinations[widget.navigationShell.currentIndex].label,
    };
    final isSubmenu = switch (widget.location) {
      '/' || '/routes' || '/logistics' || '/profile' => false,
      _ => true,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: isSubmenu ? BackButton(onPressed: () => context.pop()) : null,
        actions: widget.location == '/'
            ? [
                IconButton(
                  tooltip: 'Profil',
                  onPressed: () => context.go('/profile'),
                  icon: const Icon(Icons.person_outline),
                ),
                IconButton(
                  key: const Key('home-chat-ai'),
                  tooltip: 'Chat AI',
                  onPressed: () => context.push('/assistant'),
                  icon: const Icon(Icons.help_outline),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        top: false,
        child: ActiveNavigationBranch(
          index: widget.navigationShell.currentIndex,
          child: widget.navigationShell,
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outline,
              width: 2,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (index) {
            widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            );
          },
          destinations: [
            for (final item in _destinations)
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }
}
