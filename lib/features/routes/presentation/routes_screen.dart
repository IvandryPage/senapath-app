import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/senapath_design.dart';
import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../../../core/widgets/feature_state_view.dart';
import '../../emergency/presentation/emergency_cubit.dart';
import '../../profile/presentation/profile_cubit.dart';
import '../domain/gps_movement_bearing.dart';
import '../domain/saved_route.dart';
import 'routes_cubit.dart';
import 'explore_map.dart';
import '../../session/domain/ride_session.dart';
import '../../session/presentation/session_cubit.dart';
import '../../session/presentation/session_screen.dart';
import '../../workouts/presentation/interval_workout_cubit.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  bool _northUpLocked = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeScreen());
  }

  Future<void> _initializeScreen() async {
    final sessionCubit = context.read<RideSessionCubit>();
    final routesCubit = context.read<RoutesCubit>();
    await Future.wait([sessionCubit.initialize(), routesCubit.load()]);
    if (mounted) sessionCubit.setActiveRoute(routesCubit.state.sessionRoute);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RoutesCubit, RoutesState>(
      listenWhen: (previous, current) =>
          previous.message != current.message && current.message != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.message!)));
        context.read<RoutesCubit>().clearMessage();
      },
      child: BlocBuilder<RoutesCubit, RoutesState>(
        builder: (context, state) {
          return BlocListener<RideSessionCubit, RideSessionState>(
            listenWhen: (previous, current) =>
                previous.message != current.message && current.message != null,
            listener: (context, state) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.message!)));
              context.read<RideSessionCubit>().clearMessage();
            },
            child: BlocBuilder<RideSessionCubit, RideSessionState>(
              builder: (context, sessionState) {
                final unitSystem = context
                    .watch<UnitSettingsCubit>()
                    .state
                    .unitSystem;
                final workoutState = context
                    .watch<IntervalWorkoutCubit>()
                    .state;
                final trackPoints = [
                  for (final location in sessionState.recordedLocations)
                    LatLng(location.latitude, location.longitude),
                ];
                final currentLocation = sessionState.recordedLocations.isEmpty
                    ? null
                    : sessionState.recordedLocations.last;
                final session = sessionState.session;
                final sessionStatus = session?.status;
                final hasActiveSession =
                    sessionStatus == RideSessionStatus.recording ||
                    sessionStatus == RideSessionStatus.paused;
                final movementBearing =
                    sessionStatus == RideSessionStatus.recording &&
                        !_northUpLocked
                    ? gpsMovementBearing(
                        sessionState.recordedLocations,
                        now: sessionState.now ?? DateTime.now().toUtc(),
                      )
                    : null;
                final activeRoute = state.sessionRoute;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ExploreMap(
                          routes: activeRoute == null
                              ? const []
                              : [activeRoute],
                          height: constraints.maxHeight,
                          trackPoints: trackPoints,
                          currentLocation: currentLocation == null
                              ? null
                              : LatLng(
                                  currentLocation.latitude,
                                  currentLocation.longitude,
                                ),
                          followLocation:
                              sessionState.session?.status ==
                              RideSessionStatus.recording,
                          movementBearingDegrees: movementBearing,
                          northUpLocked: _northUpLocked,
                          onToggleNorthUp: () =>
                              setState(() => _northUpLocked = !_northUpLocked),
                          showEmptyMessage: false,
                        ),
                        if (hasActiveSession && session != null)
                          Positioned(
                            right: 16,
                            bottom: 84,
                            child: _SessionMetricsOverlay(
                              speedMetersPerSecond:
                                  session.currentSpeedMetersPerSecond,
                              distanceMeters: session.distanceMeters,
                              unitSystem: unitSystem,
                            ),
                          ),
                        Positioned(
                          top: 12,
                          left: 16,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth - 104,
                            ),
                            child: activeRoute == null
                                ? FilledButton.tonalIcon(
                                    onPressed: state.isLoading
                                        ? null
                                        : _openGpxPicker,
                                    icon: const Icon(Icons.search),
                                    label: const Text('Cari rute GPX'),
                                  )
                                : _SelectedRouteControl(
                                    route: activeRoute,
                                    onChange: state.isLoading
                                        ? null
                                        : _openGpxPicker,
                                    onRemove: () => context
                                        .read<RoutesCubit>()
                                        .selectSessionRoute(null),
                                  ),
                          ),
                        ),
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: hasActiveSession
                              ? FloatingActionButton.extended(
                                  tooltip: 'Detail sesi',
                                  onPressed: () => _openSessionDetails(context),
                                  icon: const Icon(
                                    Icons.monitor_heart_outlined,
                                  ),
                                  label: const Text('Detail sesi'),
                                )
                              : FloatingActionButton.extended(
                                  key: const Key('start-session-button'),
                                  tooltip: 'Mulai sesi',
                                  onPressed: sessionState.isCheckingReadiness
                                      ? null
                                      : () => context
                                            .read<RideSessionCubit>()
                                            .start(
                                              route: activeRoute,
                                              workout:
                                                  workoutState.selectedWorkout,
                                            ),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Mulai sesi'),
                                ),
                        ),
                        if (!hasActiveSession)
                          Positioned(
                            left: 16,
                            bottom: 16,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * 0.45,
                              ),
                              child: OutlinedButton.icon(
                                onPressed: workoutState.isLoading
                                    ? null
                                    : () => context.push('/routes/workouts'),
                                icon: const Icon(Icons.timer_outlined),
                                label: Text(
                                  workoutState.selectedWorkout == null
                                      ? 'Workout'
                                      : 'Workout dipilih',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openGpxPicker() async {
    final routesCubit = context.read<RoutesCubit>();
    await routesCubit.load();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _GpxRoutePicker(),
    );
  }

  Future<void> _openSessionDetails(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: context.read<RideSessionCubit>()),
              BlocProvider.value(value: context.read<RoutesCubit>()),
              BlocProvider.value(value: context.read<IntervalWorkoutCubit>()),
              BlocProvider.value(value: context.read<UnitSettingsCubit>()),
              BlocProvider.value(value: context.read<ProfileCubit>()),
              BlocProvider.value(value: context.read<EmergencyCubit>()),
            ],
            child: Scaffold(
              appBar: AppBar(title: const Text('Detail sesi')),
              body: SessionScreen(
                showMap: false,
                showHistory: false,
                showSummary: false,
                compactControls: true,
                hideReadinessDetails: true,
              ),
            ),
          ),
        ),
      );
}

class _SelectedRouteControl extends StatelessWidget {
  const _SelectedRouteControl({
    required this.route,
    required this.onChange,
    required this.onRemove,
  });

  final RouteRecord route;
  final VoidCallback? onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => SenapathCard(
    child: Padding(
      padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
      child: Row(
        children: [
          const Icon(Icons.route_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              route.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            tooltip: 'Ganti GPX',
            onPressed: onChange,
            icon: const Icon(Icons.swap_horiz),
          ),
          IconButton(
            tooltip: 'Hapus GPX dari peta',
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    ),
  );
}

class _GpxRoutePicker extends StatefulWidget {
  const _GpxRoutePicker();

  @override
  State<_GpxRoutePicker> createState() => _GpxRoutePickerState();
}

class _GpxRoutePickerState extends State<_GpxRoutePicker> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<RoutesCubit, RoutesState>(
    builder: (context, state) {
      final routes = state.routes
          .where((route) => route.points.length >= 2)
          .toList(growable: false);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih rute GPX',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('explore-gpx-search'),
                controller: _searchController,
                onChanged: context.read<RoutesCubit>().search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Cari nama rute',
                  suffixIcon: state.query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Hapus pencarian',
                          onPressed: () {
                            _searchController.clear();
                            context.read<RoutesCubit>().search('');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: state.isLoading
                    ? null
                    : context.read<RoutesCubit>().importGpx,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Impor GPX'),
              ),
              if (state.isLoading) const LinearProgressIndicator(),
              if (state.message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    state.message!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: routes.isEmpty
                    ? Center(
                        child: Text(
                          state.query.isEmpty
                              ? 'Belum ada rute GPX yang siap ditampilkan.'
                              : 'Tidak ada rute GPX dengan nama “${state.query}”.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: routes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final route = routes[index];
                          return SenapathCard(
                            child: ListTile(
                              leading: const Icon(Icons.route_outlined),
                              title: Text(route.name),
                              subtitle: Text(
                                '${route.points.length} titik · ${route.source}',
                              ),
                              trailing: const Icon(Icons.map_outlined),
                              onTap: () {
                                context.read<RoutesCubit>().selectSessionRoute(
                                  route,
                                );
                                Navigator.of(context).pop();
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SessionMetricsOverlay extends StatelessWidget {
  const _SessionMetricsOverlay({
    required this.speedMetersPerSecond,
    required this.distanceMeters,
    required this.unitSystem,
  });

  final double speedMetersPerSecond;
  final double distanceMeters;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final metric = unitSystem == UnitSystem.metric;
    final speed = speedMetersPerSecond.isFinite
        ? speedMetersPerSecond * (metric ? 3.6 : 2.236936)
        : null;
    final distance = distanceMeters.isFinite
        ? metric
              ? distanceMeters / 1000
              : distanceMeters / 1609.344
        : null;
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      label:
          'Kecepatan ${speed == null ? 'tidak tersedia' : '${speed.toStringAsFixed(1)} ${metric ? 'km/j' : 'mph'}'}, '
          'jarak ${distance == null ? 'tidak tersedia' : '${distance.toStringAsFixed(2)} ${metric ? 'km' : 'mi'}'}',
      child: Container(
        constraints: const BoxConstraints(minWidth: 132),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              speed == null
                  ? '— ${metric ? 'km/j' : 'mph'}'
                  : '${speed.toStringAsFixed(1)} ${metric ? 'km/j' : 'mph'}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Jarak  ${distance == null ? '—' : distance.toStringAsFixed(2)} ${metric ? 'km' : 'mi'}',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class SavedRoutesScreen extends StatefulWidget {
  const SavedRoutesScreen({super.key});

  @override
  State<SavedRoutesScreen> createState() => _SavedRoutesScreenState();
}

class _SavedRoutesScreenState extends State<SavedRoutesScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    context.read<RoutesCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutesCubit, RoutesState>(
      builder: (context, state) {
        final unitSystem = context.watch<UnitSettingsCubit>().state.unitSystem;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            Text(
              'Perpustakaan rute',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Cari dan kelola rute GPX. Pilih rute untuk langsung '
              'menampilkannya di peta Jelajah.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: state.isLoading
                    ? null
                    : context.read<RoutesCubit>().importGpx,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Impor berkas GPX'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('gpx-route-search'),
              onChanged: context.read<RoutesCubit>().search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Cari nama rute GPX',
                suffixIcon: state.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        onPressed: () => context.read<RoutesCubit>().search(''),
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (state.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: FeatureStateView.loading(),
                ),
              )
            else if (state.routes.isEmpty)
              SenapathCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    state.query.isEmpty
                        ? 'Belum ada rute GPX. Impor berkas dari perangkat.'
                        : 'Tidak ada rute GPX dengan nama “${state.query}”.',
                  ),
                ),
              )
            else
              for (final route in state.routes)
                _RouteTile(route: route, unitSystem: unitSystem),
          ],
        );
      },
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({required this.route, required this.unitSystem});

  final RouteRecord route;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final distance = route.distanceMeters == null
        ? 'Jarak tidak tersedia'
        : _formatDistance(route.distanceMeters!, unitSystem);
    final elevation = route.elevationGainMeters == null
        ? 'Elevasi tidak tersedia'
        : '+${_formatElevation(route.elevationGainMeters!, unitSystem)}';
    final poi = route.poiSummary.isEmpty
        ? 'POI belum tersedia'
        : route.poiSummary;
    final description = route.description;

    return SenapathCard(
      child: ListTile(
        onTap: () => _showRoutePreview(context),
        leading: const Icon(Icons.route_outlined),
        title: Text(route.name),
        subtitle: Text(
          '$distance · $elevation\n'
          '${description.isEmpty ? '' : '$description\n'}'
          '$poi\nSumber: ${route.source}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            route.availability == 'offline'
                ? const Tooltip(
                    message: 'Tersedia offline',
                    child: Icon(Icons.cloud_off_outlined),
                  )
                : const Icon(Icons.cloud_done_outlined),
            if (route.source == 'GPX lokal')
              IconButton(
                tooltip: 'Hapus rute GPX ${route.name}',
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Hapus rute GPX?'),
        content: Text(
          '“${route.name}” akan dihapus dari rute tersimpan. Tindakan ini '
          'tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Hapus rute'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<RoutesCubit>().deleteImportedRoute(route.id);
    }
  }

  void _showRoutePreview(BuildContext context) {
    final distance = route.distanceMeters == null
        ? 'Jarak tidak tersedia'
        : _formatDistance(
            route.distanceMeters!,
            context.read<UnitSettingsCubit>().state.unitSystem,
          );
    final elevation = route.elevationGainMeters == null
        ? 'Elevasi tidak tersedia'
        : '+${_formatElevation(route.elevationGainMeters!, context.read<UnitSettingsCubit>().state.unitSystem)}';
    final poi = route.poiSummary.isEmpty
        ? 'POI belum tersedia'
        : route.poiSummary;
    final router = GoRouter.maybeOf(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(route.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                route.points.isEmpty
                    ? 'Geometri belum tersimpan untuk rute ini.'
                    : route.source == 'GPX lokal'
                    ? 'Jejak GPX lokal · ${route.points.length} titik · tersedia offline'
                    : 'Rute online · ${route.points.length} titik · perlu koneksi',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (route.points.length >= 2)
                RouteMapPreview(points: route.points, source: route.source)
              else
                const SizedBox(
                  height: 180,
                  child: Center(child: Icon(Icons.route_outlined, size: 44)),
                ),
              const SizedBox(height: 12),
              Text('$distance · $elevation · $poi'),
              if (route.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(route.description),
              ],
              if (route.points.length >= 2) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      context.read<RoutesCubit>().selectSessionRoute(route);
                      Navigator.of(context).pop();
                      router?.go('/routes');
                    },
                    icon: const Icon(Icons.navigation),
                    label: const Text('Tampilkan di Jelajah'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDistance(double meters, UnitSystem unitSystem) {
    if (unitSystem == UnitSystem.metric) {
      return meters >= 1000
          ? '${(meters / 1000).toStringAsFixed(1)} km'
          : '${meters.toStringAsFixed(0)} m';
    }
    return meters >= 1609.344
        ? '${(meters / 1609.344).toStringAsFixed(1)} mi'
        : '${(meters * 3.28084).toStringAsFixed(0)} ft';
  }

  String _formatElevation(double meters, UnitSystem unitSystem) =>
      unitSystem == UnitSystem.metric
      ? '${meters.toStringAsFixed(0)} m'
      : '${(meters * 3.28084).toStringAsFixed(0)} ft';
}

class RouteMapPreview extends StatefulWidget {
  const RouteMapPreview({
    required this.points,
    this.source = 'GPX lokal',
    this.currentPosition,
    this.height = 220,
    super.key,
  });

  final List<RoutePoint> points;
  final String source;
  final RoutePoint? currentPosition;
  final double? height;

  @override
  State<RouteMapPreview> createState() => _RouteMapPreviewState();
}

class _RouteMapPreviewState extends State<RouteMapPreview> {
  bool _hasTileError = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final routePoints = widget.points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    final position = widget.currentPosition;
    final positionPoint = position == null
        ? null
        : LatLng(position.latitude, position.longitude);

    return Semantics(
      label:
          'Peta OpenStreetMap dengan ${widget.source == 'GPX lokal' ? 'jejak' : 'jalur'} ${widget.source} ${widget.points.length} titik'
          '${position == null ? '' : ' dan posisi GPS'}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.height == null ? 0 : 20),
        child: SizedBox(
          width: double.infinity,
          height: widget.height,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: routePoints.isEmpty
                      ? const LatLng(-7.7956, 110.3695)
                      : routePoints.first,
                  initialCameraFit: routePoints.length < 2
                      ? null
                      : CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(routePoints),
                          padding: const EdgeInsets.all(32),
                        ),
                  minZoom: 3,
                  maxZoom: 18,
                  backgroundColor: colors.surfaceContainerHighest,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.senapath',
                    maxZoom: 19,
                    errorTileCallback: (_, _, _) {
                      if (mounted && !_hasTileError) {
                        setState(() => _hasTileError = true);
                      }
                    },
                  ),
                  if (routePoints.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          strokeWidth: 5,
                          color: SenapathColors.accent,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (routePoints.isNotEmpty)
                        Marker(
                          point: routePoints.first,
                          width: 32,
                          height: 36,
                          child: Icon(
                            Icons.trip_origin,
                            color: SenapathColors.blue,
                            size: 28,
                          ),
                        ),
                      if (routePoints.length >= 2)
                        Marker(
                          point: routePoints.last,
                          width: 32,
                          height: 36,
                          child: Icon(
                            Icons.flag,
                            color: SenapathColors.accent,
                            size: 28,
                          ),
                        ),
                      if (positionPoint != null)
                        Marker(
                          point: positionPoint,
                          width: 32,
                          height: 36,
                          child: Icon(
                            Icons.my_location,
                            color: SenapathColors.ink,
                            size: 28,
                          ),
                        ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap: () => launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_hasTileError)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Material(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        'Basemap tidak tersedia. Jejak GPX tetap ditampilkan.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
