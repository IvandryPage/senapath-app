import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/overview/presentation/overview_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/routes/presentation/routes_screen.dart';
import '../../features/session/presentation/session_screen.dart';
import '../../features/logistics/presentation/logistics_screen.dart';
import '../../features/authentication/presentation/device_auth_cubit.dart';
import '../../features/authentication/presentation/device_unlock_screen.dart';

const _destinations = <({String label, IconData icon, IconData selectedIcon})>[
  (label: 'Beranda', icon: Icons.home_outlined, selectedIcon: Icons.home),
  (label: 'Rute', icon: Icons.map_outlined, selectedIcon: Icons.map),
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
          _AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const OverviewScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/routes',
              builder: (context, state) => const RoutesScreen(),
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
            ),
          ],
        ),
      ],
    ),
  ],
);

class _AppShell extends StatefulWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  @override
  void initState() {
    super.initState();
    context.read<DeviceAuthCubit>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<DeviceAuthCubit>().state;
    if (!authState.isUnlocked) {
      return const Scaffold(body: SafeArea(child: DeviceUnlockScreen()));
    }

    final destination = _destinations[widget.navigationShell.currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(destination.label),
        actions: [
          if (widget.navigationShell.currentIndex == 4)
            IconButton(
              tooltip: 'Keluar',
              onPressed: () => context.read<DeviceAuthCubit>().logout(),
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
