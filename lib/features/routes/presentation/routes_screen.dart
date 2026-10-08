import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/senapath_design.dart';
import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../../../core/widgets/feature_state_view.dart';
import '../domain/saved_route.dart';
import 'google_directions_map.dart';
import 'routes_cubit.dart';
import 'explore_map.dart';
import '../../session/domain/ride_session.dart';
import '../../session/presentation/session_cubit.dart';
import '../../session/presentation/session_screen.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final _destinationController = TextEditingController();
  final _destinationFocusNode = FocusNode();

  @override
  void dispose() {
    _destinationController.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
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
          final unitSystem = context
              .watch<UnitSettingsCubit>()
              .state
              .unitSystem;
          return BlocBuilder<RideSessionCubit, RideSessionState>(
            builder: (context, sessionState) {
              final trackPoints = [
                for (final location in sessionState.recordedLocations)
                  LatLng(location.latitude, location.longitude),
              ];
              final currentLocation = sessionState.recordedLocations.isEmpty
                  ? null
                  : sessionState.recordedLocations.last;
              final currentRoutePoint = currentLocation == null
                  ? null
                  : RoutePoint(
                      latitude: currentLocation.latitude,
                      longitude: currentLocation.longitude,
                      elevationMeters: currentLocation.altitudeMeters,
                    );
              final sessionStatus = sessionState.session?.status;
              final hasActiveSession =
                  sessionStatus == RideSessionStatus.recording ||
                  sessionStatus == RideSessionStatus.paused;
              final activeRoute = hasActiveSession
                  ? state.sessionRouteSelected
                        ? state.sessionRoute
                        : state.plannedRoute
                  : state.plannedRoute;
              return LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (activeRoute?.source.startsWith('Google Maps') == true)
                        GoogleDirectionsMap(
                          route: activeRoute!,
                          currentPosition: currentRoutePoint,
                          trackPoints: trackPoints,
                          followCurrentPosition:
                              sessionState.session?.status ==
                              RideSessionStatus.recording,
                          height: constraints.maxHeight,
                        )
                      else
                        ExploreMap(
                          routes: activeRoute == null ? const [] : [activeRoute],
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
                        ),
                      const Positioned.fill(
                        child: SessionScreen(
                          showMap: false,
                          showHistory: false,
                          showSummary: false,
                          initialPanelSize: 0.42,
                          compactControls: true,
                        ),
                      ),
                      if (!hasActiveSession) ...[
                        Positioned(
                          top: 12,
                          left: 16,
                          right: 16,
                          child: _buildMapSearch(state),
                        ),
                        if (state.plannedRoute != null)
                          Positioned(
                            left: 16,
                            right: 16,
                            top: 132,
                            child: _buildPlannedRouteCard(
                              state.plannedRoute!,
                              unitSystem,
                              isSelected:
                                  state.sessionRoute?.id ==
                                  state.plannedRoute!.id,
                            ),
                          ),
                      ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMapSearch(RoutesState state) {
    final colors = Theme.of(context).colorScheme;
    return SenapathCard(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      margin: const EdgeInsets.only(left: 4, right: 9, top: 4, bottom: 9),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.my_location, color: colors.primary, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Lokasi saya',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const Divider(height: 12),
            Row(
              children: [
                Icon(Icons.place_outlined, color: colors.error, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _destinationController,
                    focusNode: _destinationFocusNode,
                    enabled: !state.isPlanning,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchGoogleRoute(),
                    decoration: const InputDecoration(
                      hintText: 'Cari tujuan atau alamat',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Cari rute sepeda',
                  onPressed: state.isPlanning ? null : _searchGoogleRoute,
                  icon: state.isPlanning
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 30, top: 2),
                child: Text(
                  'Rute sepeda · Google Maps',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ],
      ),
    );
  }

  Widget _buildPlannedRouteCard(
    RouteRecord route,
    UnitSystem unitSystem, {
    required bool isSelected,
  }) {
    final distance = route.distanceMeters == null
        ? 'Jarak belum tersedia'
        : _formatRouteDistance(route.distanceMeters!, unitSystem);
    return SenapathCard(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(route.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('$distance · Google Maps · bukan navigasi turn-by-turn'),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSelected
                    ? null
                    : () {
                        context.read<RoutesCubit>().selectSessionRoute(route);
                        _showMessage(
                          'Rute dipilih. Rute ini akan tampil saat sesi dimulai.',
                        );
                      },
                icon: Icon(isSelected ? Icons.check : Icons.route),
                label: Text(isSelected ? 'Dipilih untuk sesi' : 'Pilih untuk sesi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchGoogleRoute() async {
    final destination = _destinationController.text.trim();
    if (destination.length < 2) {
      _showMessage('Masukkan nama tempat atau alamat tujuan.');
      return;
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage(
          'Aktifkan layanan lokasi untuk mencari rute dari lokasimu.',
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage(
          'Izin lokasi diperlukan untuk menentukan titik awal rute.',
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      await context.read<RoutesCubit>().planCyclingRoute(
        originLatitude: position.latitude,
        originLongitude: position.longitude,
        destination: destination,
      );
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Lokasi tidak dapat diperoleh. Coba lagi di area terbuka.',
        );
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
              'Rute tersimpan tidak tampil di peta Jelajah. Pilih rute saat '
              'memulai sesi untuk menampilkannya bersama jejak GPS.',
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
            if (state.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: FeatureStateView.loading(),
                ),
              )
            else if (state.routes.isEmpty)
              const SenapathCard(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Belum ada rute GPX. Impor berkas dari perangkat untuk '
                    'menyimpannya di sini.',
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
      builder: (dialogContext) => AlertDialog(
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
                route.source.startsWith('Google Maps')
                    ? GoogleDirectionsMap(route: route, height: 220)
                    : RouteMapPreview(
                        points: route.points,
                        source: route.source,
                      )
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
                      if (router == null) return;
                      Navigator.of(context).pop();
                      router.push('/routes/navigation', extra: route);
                    },
                    icon: const Icon(Icons.navigation),
                    label: const Text('Ikuti rute'),
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
                          color: SenapathColors.sky,
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
                            color: SenapathColors.spring,
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
                            color: SenapathColors.gold,
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

String _formatRouteDistance(double meters, UnitSystem unitSystem) {
  if (unitSystem == UnitSystem.metric) {
    return meters >= 1000
        ? '${(meters / 1000).toStringAsFixed(1)} km'
        : '${meters.toStringAsFixed(0)} m';
  }
  return meters >= 1609.344
      ? '${(meters / 1609.344).toStringAsFixed(1)} mi'
      : '${(meters * 3.28084).toStringAsFixed(0)} ft';
}
