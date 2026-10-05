import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../../../core/widgets/feature_state_view.dart';
import '../domain/saved_route.dart';
import 'routes_cubit.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final _searchController = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(context.read<RoutesCubit>().load());
  }

  @override
  void dispose() {
    _searchController.dispose();
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
          final unitSystem = context.watch<UnitSettingsCubit>().state.unitSystem;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (value) =>
                            context.read<RoutesCubit>().search(value),
                        decoration: InputDecoration(
                          hintText: 'Cari rute tersimpan',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: 'Hapus pencarian',
                            onPressed: () {
                              _searchController.clear();
                              context.read<RoutesCubit>().search('');
                            },
                            icon: const Icon(Icons.clear),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Impor GPX',
                      onPressed: state.isLoading
                          ? null
                          : () => context.read<RoutesCubit>().importGpx(),
                      icon: const Icon(Icons.file_upload_outlined),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildResults(state, unitSystem)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResults(RoutesState state, UnitSystem unitSystem) {
    if (state.isLoading) return const FeatureStateView.loading();
    if (state.routes.isEmpty) {
      return FeatureStateView.empty(
        title: state.query.isEmpty
            ? 'Belum ada rute tersimpan'
            : 'Rute tidak ditemukan',
        message: state.query.isEmpty
            ? 'Rute offline akan muncul setelah provider peta atau impor rute dikonfigurasi.'
            : 'Coba kata kunci lain atau periksa data rute offline.',
        icon: Icons.map_outlined,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: state.routes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _RouteTile(
        route: state.routes[index],
        unitSystem: unitSystem,
      ),
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

    return Card(
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
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
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
        : '+${_formatElevation(
            route.elevationGainMeters!,
            context.read<UnitSettingsCubit>().state.unitSystem,
          )}';
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
                    : 'Jejak GPX lokal · ${route.points.length} titik · tersedia offline',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (route.points.length >= 2)
                RouteMapPreview(points: route.points)
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
    this.currentPosition,
    super.key,
  });

  final List<RoutePoint> points;
  final RoutePoint? currentPosition;

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
          'Peta OpenStreetMap dengan jejak GPX lokal ${widget.points.length} titik'
          '${position == null ? '' : ' dan posisi GPS'}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: double.infinity,
          height: 220,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: routePoints.isEmpty
                      ? const LatLng(-6.2, 106.8)
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
                          color: colors.primary,
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
                            color: colors.tertiary,
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
                            color: colors.error,
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
                            color: colors.secondary,
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
