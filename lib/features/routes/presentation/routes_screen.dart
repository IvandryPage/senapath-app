import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/senapath_design.dart';
import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../../../core/validation/input_formatters.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/active_navigation_branch.dart';
import '../../../core/widgets/feature_state_view.dart';
import '../data/overpass_route_places_service.dart';
import '../data/pre_ride_weather_service.dart';
import '../../emergency/presentation/emergency_cubit.dart';
import '../../logistics/presentation/logistics_cubit.dart';
import '../../logistics/presentation/resupply_cache_sheet.dart';
import '../../profile/presentation/profile_cubit.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/gps_movement_bearing.dart';
import '../domain/route_wind.dart';
import '../domain/nearby_route_place.dart';
import '../domain/saved_route.dart';
import '../../ride_coach/presentation/ride_coach_cubit.dart';
import '../../ride_prediction/data/ride_history_repository.dart';
import '../../ride_prediction/domain/ride_time_predictor.dart';
import 'routes_cubit.dart';
import 'explore_map.dart';
import 'route_guidance_view.dart';
import '../data/ghost_pacer_service.dart';
import '../../session/domain/ride_session.dart';
import '../../session/presentation/session_cubit.dart';
import '../../session/presentation/session_screen.dart';
import '../../workouts/presentation/interval_workout_cubit.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({
    this.routePlacesService,
    this.preRideWeatherService,
    this.rideCoachCubit,
    super.key,
  });

  final OverpassRoutePlacesService? routePlacesService;
  final PreRideWeatherService? preRideWeatherService;
  final RideCoachCubit? rideCoachCubit;

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  late final OverpassRoutePlacesService _routePlacesService =
      widget.routePlacesService ?? OverpassRoutePlacesService();
  List<NearbyRoutePlace> _nearbyPlaces = const [];
  String? _nearbyPlacesRouteId;
  bool _isLoadingNearbyPlaces = false;

  bool _northUpLocked = false;
  bool _isExploreBranchActive = true;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeScreen());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isExploreBranchActive =
        ActiveNavigationBranch.of(context)?.isActive(1) ?? true;
  }

  Future<void> _initializeScreen() async {
    final sessionCubit = context.read<RideSessionCubit>();
    final routesCubit = context.read<RoutesCubit>();
    unawaited(context.read<ProfileCubit>().load());
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
                ..showSnackBar(
                  SnackBar(
                    backgroundColor: state.messageIsSuccess
                        ? const Color(0xFF16834A)
                        : null,
                    content: Row(
                      children: [
                        if (state.messageIsSuccess) ...[
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 10),
                        ],
                        Expanded(child: Text(state.message!)),
                      ],
                    ),
                  ),
                );
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
                final profileState = context.watch<ProfileCubit>().state;
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
                final guidanceRoute = state.guidanceRoute;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    if (guidanceRoute != null) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          RouteGuidanceView(
                            key: ValueKey(guidanceRoute.id),
                            route: guidanceRoute,
                            ambientBright: sessionState.isAmbientBright,
                            ghostPacerService: GhostPacerService(
                              history: RideSessionGhostPacerHistory(
                                context.read<RideSessionCubit>().repository,
                              ),
                            ),
                            onStop: () => context
                                .read<RoutesCubit>()
                                .endGuidance(),
                          ),
                        ],
                      );
                    }
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ExploreMap(
                          routes: activeRoute == null
                              ? const []
                              : [activeRoute],
                          nearbyPlaces: _nearbyPlacesRouteId == activeRoute?.id
                              ? _nearbyPlaces
                              : const [],
                          autoLocate: _isExploreBranchActive,
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
                          onCheckpointTap: _showResupplyCache,
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
                        if (hasActiveSession)
                          Positioned(
                            left: 16,
                            bottom: 16,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * 0.48,
                              ),
                              child: Tooltip(
                                message: 'Pilih telepon atau WhatsApp',
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .error,
                                    foregroundColor: Theme.of(context)
                                        .colorScheme
                                        .onError,
                                  ),
                                  onPressed: !profileState.isLoaded
                                      ? null
                                      : profileState.contacts.isEmpty
                                      ? () => context.push('/profile')
                                      : () => _showEmergencyOptions(
                                          profileState.contacts.first,
                                          currentLocation,
                                        ),
                                  icon: Icon(
                                    profileState.contacts.isEmpty
                                        ? Icons.person_add_alt_1
                                        : Icons.sos,
                                  ),
                                  label: Text(
                                    !profileState.isLoaded
                                        ? 'Memuat kontak…'
                                        : profileState.contacts.isEmpty
                                        ? 'Tambah kontak darurat'
                                        : 'SOS darurat',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 12,
                          left: 16,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth - 104,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                activeRoute == null
                                    ? FilledButton.tonalIcon(
                                        onPressed: state.isLoading
                                            ? null
                                            : _openGpxPicker,
                                        icon: const Icon(Icons.search),
                                        label: const Text('Pilih file rute'),
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
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  key: const Key('explore-saved-routes'),
                                  onPressed: () =>
                                      context.push('/routes/saved'),
                                  icon: const Icon(Icons.history_outlined),
                                  label: const Text('Rute tersimpan'),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surface,
                                  ),
                                ),
                                if (activeRoute != null &&
                                    activeRoute.points.length >= 2) ...[
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    key: const Key('route-nearby-places'),
                                    onPressed: _isLoadingNearbyPlaces
                                        ? null
                                        : () =>
                                              _nearbyPlacesRouteId ==
                                                  activeRoute.id
                                              ? _showNearbyPlaces(_nearbyPlaces)
                                              : _confirmAndLoadNearbyPlaces(
                                                  activeRoute,
                                                ),
                                    icon: _isLoadingNearbyPlaces
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Icon(
                                            _nearbyPlacesRouteId ==
                                                    activeRoute.id
                                                ? Icons.place
                                                : Icons.search,
                                          ),
                                    label: Text(
                                      _isLoadingNearbyPlaces
                                          ? 'Mencari fasilitas…'
                                          : _nearbyPlacesRouteId ==
                                                activeRoute.id
                                          ? 'Fasilitas (${_nearbyPlaces.length})'
                                          : 'Cari fasilitas',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .surface,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: hasActiveSession
                              ? FloatingActionButton.extended(
                                  tooltip: 'Detail perjalanan',
                                  onPressed: () => _openSessionDetails(context),
                                  icon: const Icon(
                                    Icons.monitor_heart_outlined,
                                  ),
                                  label: const Text('Detail perjalanan'),
                                )
                              : FloatingActionButton.extended(
                                  key: const Key('start-session-button'),
                                  tooltip: 'Mulai merekam',
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
                                  label: const Text('Mulai merekam'),
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
                                      ? 'Latihan'
                                      : 'Latihan dipilih',
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

  Future<void> _confirmAndLoadNearbyPlaces(RouteRecord route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Cari fasilitas sekitar rute?'),
        content: const Text(
          'Koordinat rute akan dikirim ke layanan publik Overpass API untuk '
          'mencari stasiun kereta, terminal, klinik, dan bengkel sepeda dalam '
          'jarak sekitar 700 meter. Permintaan dilakukan saat kamu memilih '
          'Cari, dan hasilnya berasal dari OpenStreetMap.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Kirim koordinat & cari'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoadingNearbyPlaces = true);
    try {
      final places = await _routePlacesService.findAlongRoute(route);
      if (!mounted) return;
      setState(() {
        _nearbyPlaces = places;
        _nearbyPlacesRouteId = route.id;
        _isLoadingNearbyPlaces = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              places.isEmpty
                  ? 'Fasilitas di sekitar rute tidak ditemukan.'
                  : '${places.length} fasilitas ditemukan dan ditandai di peta.',
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingNearbyPlaces = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Fasilitas sekitar rute tidak dapat dimuat. Periksa koneksi '
              'internet dan coba lagi.',
            ),
          ),
        );
    }
  }

  Future<void> _showNearbyPlaces(
    List<NearbyRoutePlace> places,
  ) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fasilitas sekitar rute',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Data OpenStreetMap · pencarian sekitar 700 m dari rute',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: places.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Tidak ada fasilitas yang ditemukan di sekitar '
                          'rute. Data OpenStreetMap mungkin belum lengkap.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: places.length,
                      itemBuilder: (context, index) {
                        final place = places[index];
                        return ListTile(
                          leading: Icon(_placeIcon(place.category)),
                          title: Text(place.name),
                          subtitle: Text(place.category.label),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () async {
                            final opened = await launchUrl(place.osmUri);
                            if (!opened && sheetContext.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Lokasi OpenStreetMap tidak dapat dibuka.',
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );

  IconData _placeIcon(NearbyRoutePlaceCategory category) => switch (category) {
    NearbyRoutePlaceCategory.trainStation => Icons.train,
    NearbyRoutePlaceCategory.busTerminal => Icons.directions_bus,
    NearbyRoutePlaceCategory.clinic => Icons.local_hospital,
    NearbyRoutePlaceCategory.bicycleRepair => Icons.pedal_bike,
  };

  Future<void> _callEmergencyContact(EmergencyContact contact) async {
    final emergencyCubit = context.read<EmergencyCubit>();
    emergencyCubit.clearMessage();
    await emergencyCubit.callContact(contact);
    _showEmergencyResult(emergencyCubit);
  }

  Future<void> _messageEmergencyContact(
    EmergencyContact contact,
    TelemetryLocation? lastLocation,
  ) async {
    final emergencyCubit = context.read<EmergencyCubit>();
    emergencyCubit.clearMessage();
    await emergencyCubit.openWhatsApp(contact, lastLocation: lastLocation);
    _showEmergencyResult(emergencyCubit);
  }

  Future<void> _showEmergencyOptions(
    EmergencyContact contact,
    TelemetryLocation? lastLocation,
  ) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pilih cara menghubungi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text('${contact.name} · ${contact.phone}'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                unawaited(_callEmergencyContact(contact));
              },
              icon: const Icon(Icons.call),
              label: const Text('Telepon biasa'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                unawaited(_messageEmergencyContact(contact, lastLocation));
              },
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Kirim pesan WhatsApp'),
            ),
            const SizedBox(height: 8),
            Text(
              lastLocation == null ? 'Lokasi perjalanan belum tersedia.' : 'Pesan WhatsApp akan menyertakan lokasi terakhir yang direkam.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );

  void _showEmergencyResult(EmergencyCubit emergencyCubit) {
    if (!mounted) return;
    final message = emergencyCubit.state.message;
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    emergencyCubit.clearMessage();
  }

  void _showResupplyCache(RouteRecord route, RouteCheckpoint checkpoint) {
    unawaited(context.read<LogisticsCubit>().load());
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      showDragHandle: false,
      builder: (_) =>
          ResupplyCacheSheet(routeName: route.name, checkpoint: checkpoint),
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
              appBar: AppBar(title: const Text('Detail perjalanan')),
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
            tooltip: 'Ganti rute',
            onPressed: onChange,
            icon: const Icon(Icons.swap_horiz),
          ),
          IconButton(
            tooltip: 'Hapus rute dari peta',
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
                'Pilih rute tersimpan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('explore-gpx-search'),
                controller: _searchController,
                onChanged: context.read<RoutesCubit>().search,
                inputFormatters: [
                  const SingleLineInputFormatter(),
                  const ForbiddenCharactersInputFormatter(),
                  LengthLimitingTextInputFormatter(
                    InputLimits.searchQueryMaxLength,
                  ),
                ],
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
                label: const Text('Impor file rute'),
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
                              ? 'Belum ada rute. Impor file GPX untuk menambahkan rute.'
                              : 'Tidak ada rute bernama “${state.query}”.',
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
                                '${route.points.length} titik rute',
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
  const SavedRoutesScreen({
    this.preRideWeatherService,
    this.rideCoachCubit,
    this.rideHistoryRepository,
    super.key,
  });

  final PreRideWeatherService? preRideWeatherService;
  final RideCoachCubit? rideCoachCubit;
  final RideHistoryRepository? rideHistoryRepository;

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
              'Rute tersimpan',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Cari rute yang kamu simpan atau impor file GPX. Pilih rute untuk melihatnya di peta.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: state.isLoading
                    ? null
                    : context.read<RoutesCubit>().importGpx,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Impor file GPX'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('gpx-route-search'),
              onChanged: context.read<RoutesCubit>().search,
              inputFormatters: [
                const SingleLineInputFormatter(),
                const ForbiddenCharactersInputFormatter(),
                LengthLimitingTextInputFormatter(
                  InputLimits.searchQueryMaxLength,
                ),
              ],
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Cari nama rute',
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
                        ? 'Belum ada rute. Impor file GPX dari ponsel.'
                        : 'Tidak ada rute bernama “${state.query}”.',
                  ),
                ),
              )
            else
              for (final route in state.routes)
                _RouteTile(
                  route: route,
                  unitSystem: unitSystem,
                  weatherService: widget.preRideWeatherService,
                  rideCoachCubit: widget.rideCoachCubit,
                  rideHistoryRepository: widget.rideHistoryRepository,
                ),
          ],
        );
      },
    );
  }
}

class _PreRideBriefing extends StatefulWidget {
  const _PreRideBriefing({
    required this.route,
    required this.weatherService,
    required this.rideCoachCubit,
  });

  final RouteRecord route;
  final PreRideWeatherService weatherService;
  final RideCoachCubit rideCoachCubit;

  @override
  State<_PreRideBriefing> createState() => _PreRideBriefingState();
}

class _PreRideBriefingState extends State<_PreRideBriefing> {
  bool _isLoadingWeather = false;
  String? _weatherError;

  Future<void> _requestBriefing() async {
    final coach = widget.rideCoachCubit;
    if (!coach.isConfigured) {
      setState(
        () => _weatherError = 'Layanan briefing AI belum dikonfigurasi.',
      );
      return;
    }
    if (!coach.isSignedIn) {
      setState(
        () => _weatherError = 'Masuk ke akun online untuk meminta briefing AI.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Buat briefing pra-perjalanan?'),
        content: const Text(
          'Setelah disetujui, titik awal rute akan dikirim ke Open-Meteo untuk mengambil cuaca saat ini. Ringkasan nama rute, jarak, elevasi, dan cuaca akan dikirim secara aman ke Supabase/Gemini. Titik GPS dan jejak lengkap rute tidak dikirim ke AI.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Setuju dan buat'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoadingWeather = true;
      _weatherError = null;
    });
    try {
      final start = widget.route.points.first;
      final weather = await widget.weatherService.fetchCurrentWeather(
        latitude: start.latitude,
        longitude: start.longitude,
      );
      final heading = routeHeadingDegrees(widget.route.points, 0);
      final windRelation = relativeWindDescription(
        windFromDegrees: weather.windDirectionFromDegrees,
        routeHeadingDegrees: heading,
      );
      final profile = _elevationProfile(widget.route.points);
      if (profile.isEmpty) {
        throw StateError('Profil elevasi rute tidak tersedia.');
      }
      final distanceKm =
          widget.route.distanceMeters != null &&
              widget.route.distanceMeters!.isFinite &&
              widget.route.distanceMeters! > 0
          ? widget.route.distanceMeters! / 1000
          : _distanceMeters(widget.route.points) / 1000;
      if (!distanceKm.isFinite || distanceKm <= 0 || distanceKm > 1000) {
        throw StateError('Jarak rute tidak valid untuk membuat briefing.');
      }
      final ascentMeters =
          widget.route.elevationGainMeters != null &&
              widget.route.elevationGainMeters!.isFinite &&
              widget.route.elevationGainMeters! >= 0
          ? widget.route.elevationGainMeters!
          : _ascentMeters(widget.route.points);
      await coach.prepareRide(
        routeId: widget.route.id,
        consent: true,
        routeAndWeather: {
          'routeName': widget.route.name,
          'distanceKm': distanceKm,
          'ascentMeters': ascentMeters,
          'elevationProfile': profile,
          'weather': weather.toBriefingJson(windRelation: windRelation),
          'routeHeadingDegrees': heading,
          'windRelation': windRelation,
        },
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _weatherError = error is StateError
              ? error.message
              : 'Cuaca rute tidak dapat dimuat. Periksa koneksi dan coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingWeather = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RideCoachCubit, RideCoachState>(
      bloc: widget.rideCoachCubit,
      builder: (context, state) {
        final briefing = state.preRideRouteId == widget.route.id
            ? state.preRideBriefing
            : null;
        final error =
            _weatherError ??
            (state.preRideRouteId == widget.route.id
                ? state.preRideError
                : null);
        final loading =
            _isLoadingWeather ||
            (state.preRideRouteId == widget.route.id && state.isLoadingPreRide);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Briefing taktis',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                if (briefing != null) ...[
                  const SizedBox(height: 8),
                  Text(briefing),
                ] else ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Ringkasan elevasi dan cuaca membantu menyiapkan strategi sebelum mulai.',
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : _requestBriefing,
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      loading
                          ? 'Menyiapkan briefing…'
                          : briefing == null
                          ? 'Buat briefing'
                          : 'Perbarui briefing',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RouteTimePredictionPreview extends StatefulWidget {
  const _RouteTimePredictionPreview({
    required this.route,
    required this.repository,
  });

  final RouteRecord route;
  final RideHistoryRepository repository;

  @override
  State<_RouteTimePredictionPreview> createState() =>
      _RouteTimePredictionPreviewState();
}

class _RouteTimePredictionPreviewState
    extends State<_RouteTimePredictionPreview> {
  Future<RideTimePrediction?>? _prediction;
  double? _distanceKm;
  double? _routeAscentMeters;

  @override
  void initState() {
    super.initState();
    _loadPrediction();
  }

  void _loadPrediction() {
    final route = widget.route;
    final routeDistanceMeters = route.distanceMeters;
    final distanceMeters =
        routeDistanceMeters != null &&
            routeDistanceMeters.isFinite &&
            routeDistanceMeters > 0
        ? routeDistanceMeters
        : _distanceMeters(route.points);
    final routeAscent = route.elevationGainMeters;
    final routeAscentMeters =
        routeAscent != null && routeAscent.isFinite && routeAscent >= 0
        ? routeAscent
        : _ascentMeters(route.points);

    _distanceKm = distanceMeters.isFinite && distanceMeters > 0
        ? distanceMeters / 1000
        : null;
    _routeAscentMeters = routeAscentMeters.isFinite && routeAscentMeters >= 0
        ? routeAscentMeters
        : null;
    if (_distanceKm == null || _routeAscentMeters == null) {
      _prediction = null;
      return;
    }
    _prediction = widget.repository.predict(
      distanceKm: _distanceKm!,
      elevationGainMeters: _routeAscentMeters!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined, color: colors.onSecondaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Estimasi durasi',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'PERSONAL',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSecondaryContainer,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_prediction == null)
            Text(
              'Data jarak atau elevasi rute belum cukup untuk menghitung estimasi.',
              style: TextStyle(color: colors.onSecondaryContainer),
            )
          else
            FutureBuilder<RideTimePrediction?>(
              future: _prediction,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Estimasi belum bisa dihitung dari riwayat lokal.',
                          style: TextStyle(color: colors.onSecondaryContainer),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Coba hitung ulang',
                        onPressed: () => setState(_loadPrediction),
                        icon: Icon(
                          Icons.refresh,
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                    ],
                  );
                }
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                final prediction = snapshot.data;
                if (prediction == null) {
                  return Text(
                    'Selesaikan minimal 3 gowes dengan elevasi terukur untuk estimasi personal.',
                    style: TextStyle(color: colors.onSecondaryContainer),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatPredictedDuration(prediction.durationMinutes),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: colors.onSecondaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rata-rata dari ${prediction.neighborCount} gowes serupa · offline',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSecondaryContainer),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

String _formatPredictedDuration(double durationMinutes) {
  if (!durationMinutes.isFinite || durationMinutes <= 0) {
    return 'Estimasi tidak tersedia';
  }
  final roundedMinutes = durationMinutes.round();
  final hours = roundedMinutes ~/ 60;
  final minutes = roundedMinutes.remainder(60);
  if (hours == 0) return '≈ $minutes menit';
  if (minutes == 0) return '≈ $hours jam';
  return '≈ $hours jam $minutes menit';
}

List<Map<String, double>> _elevationProfile(List<RoutePoint> points) {
  if (points.length < 2 ||
      points.any((point) => !point.elevationMeters.isFinite)) {
    return const [];
  }
  final cumulativeDistances = _cumulativeRouteDistances(points);
  final sampleCount = math.min(points.length, 24);
  final indexes = <int>{};
  if (sampleCount == 1) {
    indexes.add(0);
  } else {
    for (var index = 0; index < sampleCount; index++) {
      indexes.add((index * (points.length - 1) / (sampleCount - 1)).round());
    }
  }
  return [
    for (final index in indexes)
      {
        'distanceKm': cumulativeDistances[index] / 1000,
        'elevationMeters': points[index].elevationMeters,
      },
  ];
}

double _ascentMeters(List<RoutePoint> points) {
  var ascent = 0.0;
  for (var index = 1; index < points.length; index++) {
    final delta =
        points[index].elevationMeters - points[index - 1].elevationMeters;
    if (delta.isFinite && delta > 0) ascent += delta;
  }
  return ascent;
}

double _distanceMeters(List<RoutePoint> points) {
  final distances = _cumulativeRouteDistances(points);
  return distances.isEmpty ? 0 : distances.last;
}

List<double> _cumulativeRouteDistances(List<RoutePoint> points) {
  final distances = <double>[0];
  for (var index = 1; index < points.length; index++) {
    final first = points[index - 1];
    final second = points[index];
    final latitude1 = first.latitude * math.pi / 180;
    final latitude2 = second.latitude * math.pi / 180;
    final latitudeDelta = latitude2 - latitude1;
    final longitudeDelta = (second.longitude - first.longitude) * math.pi / 180;
    final a =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(latitude1) *
            math.cos(latitude2) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    final meters = 6371000 * 2 * math.asin(math.sqrt(a));
    distances.add(distances.last + (meters.isFinite ? meters : 0));
  }
  return distances;
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({
    required this.route,
    required this.unitSystem,
    this.weatherService,
    this.rideCoachCubit,
    this.rideHistoryRepository,
  });

  final RouteRecord route;
  final UnitSystem unitSystem;
  final PreRideWeatherService? weatherService;
  final RideCoachCubit? rideCoachCubit;
  final RideHistoryRepository? rideHistoryRepository;

  @override
  Widget build(BuildContext context) {
    final distance = route.distanceMeters == null
        ? 'Jarak tidak tersedia'
        : _formatDistance(route.distanceMeters!, unitSystem);
    final elevation = route.elevationGainMeters == null
        ? 'Elevasi tidak tersedia'
        : '+${_formatElevation(route.elevationGainMeters!, unitSystem)}';
    final poi = route.poiSummary.isEmpty
        ? 'Belum ada titik penting'
        : route.poiSummary;
    final availabilityLabel = route.availability == 'offline'
        ? 'Tersimpan di ponsel'
        : 'Perlu internet';
    final description = route.description;

    return SenapathCard(
      child: ListTile(
        onTap: () => _showRoutePreview(context),
        leading: const Icon(Icons.route_outlined),
        title: Text(route.name),
        subtitle: Text(
          '$distance · $elevation\n'
          '${description.isEmpty ? '' : '$description\n'}'
          '$poi\n$availabilityLabel',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            route.availability == 'offline'
                ? const Tooltip(
                    message: 'Bisa dibuka tanpa internet',
                    child: Icon(Icons.cloud_off_outlined),
                  )
                : const Icon(Icons.cloud_done_outlined),
            if (route.source == 'GPX lokal')
              IconButton(
                tooltip: 'Hapus rute ${route.name}',
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
        title: const Text('Hapus rute?'),
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
        ? 'Belum ada titik penting'
        : route.poiSummary;
    final router = GoRouter.maybeOf(context);
    final historyRepository = rideHistoryRepository;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
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
                      ? 'Garis rute belum tersimpan.'
                      : route.source == 'GPX lokal'
                      ? 'File rute di ponsel · ${route.points.length} titik · bisa dipakai tanpa internet'
                      : 'Rute online · ${route.points.length} titik · perlu internet',
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
                if (route.points.length >= 2 && rideCoachCubit != null) ...[
                  const SizedBox(height: 16),
                  _PreRideBriefing(
                    route: route,
                    weatherService:
                        weatherService ?? OpenMeteoPreRideWeatherService(),
                    rideCoachCubit: rideCoachCubit!,
                  ),
                ],
                if (route.points.length >= 2 && historyRepository != null) ...[
                  const SizedBox(height: 16),
                  _RouteTimePredictionPreview(
                    route: route,
                    repository: historyRepository,
                  ),
                ],
                if (route.points.length >= 2) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: router == null
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              context.read<RoutesCubit>().startGuidance(route);
                              router.go('/routes');
                            },
                      icon: const Icon(Icons.navigation),
                      label: const Text('Mulai panduan'),
                    ),
                  ),
                  const SizedBox(height: 8),
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
    this.ghostPosition,
    this.ghostHeadingDegrees,
    this.height = 220,
    super.key,
  });

  final List<RoutePoint> points;
  final String source;
  final RoutePoint? currentPosition;
  final RoutePoint? ghostPosition;
  final double? ghostHeadingDegrees;
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
    final ghostPosition = widget.ghostPosition;
    final ghostPoint = ghostPosition == null
        ? null
        : LatLng(ghostPosition.latitude, ghostPosition.longitude);

    return Semantics(
      label:
          'Peta rute dengan ${widget.points.length} titik'
          '${position == null ? '' : ' dan lokasi saat ini'}',
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
                      if (ghostPoint != null)
                        Marker(
                          point: ghostPoint,
                          width: 24,
                          height: 24,
                          child: Tooltip(
                            message: 'Hantu dari sesi terbaik sebelumnya',
                            child: Transform.rotate(
                              angle:
                                  (widget.ghostHeadingDegrees ?? 0) *
                                  math.pi /
                                  180,
                              child: Icon(
                                Icons.navigation,
                                color: colors.primary.withValues(alpha: 0.42),
                                size: 18,
                              ),
                            ),
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
                        'Peta jalan tidak tersedia. Garis rute tetap ditampilkan.',
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
