import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/overview/presentation/overview_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/profile_settings_screen.dart';
import '../../features/routes/presentation/routes_screen.dart';
import '../../features/routes/presentation/route_guidance_screen.dart';
import '../../features/routes/domain/saved_route.dart';
import '../../features/session/presentation/session_screen.dart';
import '../../features/logistics/presentation/logistics_screen.dart';
import '../../features/strategy_game/presentation/strategy_game_screen.dart';
import '../../features/authentication/presentation/device_auth_cubit.dart';
import '../../features/authentication/presentation/device_unlock_screen.dart';
import '../../features/authentication/presentation/cloud_account_screen.dart';
import '../../features/authentication/presentation/cloud_account_cubit.dart';
import '../../features/assistant/presentation/ai_chat_screen.dart';
import '../../features/assistant/presentation/ai_chat_cubit.dart';
import '../../features/feedback/presentation/feedback_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/session/domain/ride_session.dart';

const _destinations = <({String label, IconData icon, IconData selectedIcon})>[
  (label: 'Beranda', icon: Icons.home_outlined, selectedIcon: Icons.home),
  (label: 'Jelajah', icon: Icons.map_outlined, selectedIcon: Icons.map),
  (
    label: 'Sesi',
    icon: Icons.directions_bike_outlined,
    selectedIcon: Icons.directions_bike,
  ),
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
                  path: 'strategy',
                  builder: (context, state) => const StrategyGameScreen(),
                ),
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
                  builder: (context, state) => LeaderboardScreen(
                    summary: state.extra as RideSessionSummary?,
                  ),
                ),
                GoRoute(
                  path: 'account',
                  builder: (context, state) => const CloudAccountScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/routes',
              builder: (context, state) => const RoutesScreen(),
              routes: [
                GoRoute(
                  path: 'navigation',
                  builder: (context, state) =>
                      RouteGuidanceScreen(route: state.extra! as RouteRecord),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/session',
              builder: (context, state) => const SessionScreen(),
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
                  path: 'settings',
                  builder: (context, state) => const ProfileSettingsScreen(),
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
    context.read<DeviceAuthCubit>().initialize();
    context.read<CloudAccountCubit>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<DeviceAuthCubit>().state;
    if (!authState.isUnlocked) {
      return const Scaffold(body: SafeArea(child: DeviceUnlockScreen()));
    }

    final title = switch (widget.location) {
      '/strategy' => 'Strategi Rute',
      '/assistant' => 'Chat AI',
      '/feedback' => 'Saran & kesan',
      '/leaderboard' => 'Papan Peringkat',
      '/account' => 'Akun online',
      '/profile/settings' => 'Pengaturan',
      '/routes/navigation' => 'Panduan Rute',
      _ => _destinations[widget.navigationShell.currentIndex].label,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.location == '/profile')
            IconButton(
              tooltip: 'Kunci aplikasi',
              onPressed: () {
                context.read<AiChatCubit>().clearConversation();
                context.read<DeviceAuthCubit>().logout();
              },
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: SafeArea(top: false, child: widget.navigationShell),
      bottomNavigationBar: NavigationBar(
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
    );
  }
}
