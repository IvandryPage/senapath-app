import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
              Expanded(child: _buildResults(state)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResults(RoutesState state) {
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
      itemBuilder: (context, index) => _RouteTile(route: state.routes[index]),
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({required this.route});

  final RouteRecord route;

  @override
  Widget build(BuildContext context) {
    final distance = route.distanceMeters == null
        ? 'Jarak tidak tersedia'
        : '${(route.distanceMeters! / 1000).toStringAsFixed(1)} km';
    final elevation = route.elevationGainMeters == null
        ? 'Elevasi tidak tersedia'
        : '+${route.elevationGainMeters!.toStringAsFixed(0)} m';
    final poi = route.poiSummary.isEmpty
        ? 'POI belum tersedia'
        : route.poiSummary;

    return Card(
      child: ListTile(
        onTap: () => _showRoutePreview(context),
        leading: const Icon(Icons.route_outlined),
        title: Text(route.name),
        subtitle: Text('$distance · $elevation\n$poi\nSumber: ${route.source}'),
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
        : '${(route.distanceMeters! / 1000).toStringAsFixed(1)} km';
    final elevation = route.elevationGainMeters == null
        ? 'Elevasi tidak tersedia'
        : '+${route.elevationGainMeters!.toStringAsFixed(0)} m';
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
}

class RouteMapPreview extends StatelessWidget {
  const RouteMapPreview({
    required this.points,
    this.currentPosition,
    super.key,
  });

  final List<RoutePoint> points;
  final RoutePoint? currentPosition;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label:
          'Jejak rute offline dengan ${points.length} titik${currentPosition == null ? '' : ' dan posisi GPS'}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: double.infinity,
          height: 220,
          child: CustomPaint(
            painter: _RoutePathPainter(
              points: points,
              currentPosition: currentPosition,
              background: colors.surfaceContainerHighest,
              pathColor: colors.primary,
              startColor: colors.tertiary,
              endColor: colors.error,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutePathPainter extends CustomPainter {
  const _RoutePathPainter({
    required this.points,
    required this.currentPosition,
    required this.background,
    required this.pathColor,
    required this.startColor,
    required this.endColor,
  });

  final List<RoutePoint> points;
  final RoutePoint? currentPosition;
  final Color background;
  final Color pathColor;
  final Color startColor;
  final Color endColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    if (points.length < 2) return;

    final allPoints = [...points, ?currentPosition];
    final minLatitude = allPoints
        .map((point) => point.latitude)
        .reduce(math.min);
    final maxLatitude = allPoints
        .map((point) => point.latitude)
        .reduce(math.max);
    final minLongitude = allPoints
        .map((point) => point.longitude)
        .reduce(math.min);
    final maxLongitude = allPoints
        .map((point) => point.longitude)
        .reduce(math.max);
    const inset = 24.0;
    final width = math.max(1.0, size.width - inset * 2);
    final height = math.max(1.0, size.height - inset * 2);
    final longitudeSpan = math.max(0.000001, maxLongitude - minLongitude);
    final latitudeSpan = math.max(0.000001, maxLatitude - minLatitude);
    final scale = math.min(width / longitudeSpan, height / latitudeSpan);
    final renderedWidth = longitudeSpan * scale;
    final renderedHeight = latitudeSpan * scale;
    final left = (size.width - renderedWidth) / 2;
    final top = (size.height - renderedHeight) / 2;

    Offset project(RoutePoint point) => Offset(
      left + (point.longitude - minLongitude) * scale,
      size.height - top - (point.latitude - minLatitude) * scale,
    );

    final path = Path()
      ..moveTo(project(points.first).dx, project(points.first).dy);
    for (final point in points.skip(1)) {
      final offset = project(point);
      path.lineTo(offset.dx, offset.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = pathColor
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(project(points.first), 7, Paint()..color = startColor);
    canvas.drawCircle(project(points.last), 7, Paint()..color = endColor);
    if (currentPosition != null) {
      final location = project(currentPosition!);
      canvas.drawCircle(location, 11, Paint()..color = background);
      canvas.drawCircle(location, 7, Paint()..color = Colors.blue.shade700);
    }
  }

  @override
  bool shouldRepaint(_RoutePathPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.currentPosition != currentPosition ||
      oldDelegate.background != background ||
      oldDelegate.pathColor != pathColor ||
      oldDelegate.startColor != startColor ||
      oldDelegate.endColor != endColor;
}
