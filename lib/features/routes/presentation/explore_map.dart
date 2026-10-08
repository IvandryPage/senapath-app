import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/senapath_design.dart';
import '../domain/saved_route.dart';

class ExploreMap extends StatefulWidget {
  const ExploreMap({
    this.routes = const [],
    this.trackPoints = const [],
    this.currentLocation,
    this.followLocation = false,
    this.height = 280,
    this.borderRadius = 0,
    this.showLocationButton = true,
    this.showEmptyMessage = true,
    super.key,
  });

  final List<RouteRecord> routes;
  final List<LatLng> trackPoints;
  final LatLng? currentLocation;
  final bool followLocation;
  final double height;
  final double borderRadius;
  final bool showLocationButton;
  final bool showEmptyMessage;

  @override
  State<ExploreMap> createState() => _ExploreMapState();
}

class _ExploreMapState extends State<ExploreMap> {
  static const _defaultCenter = LatLng(-7.7956, 110.3695);
  MapController _mapController = MapController();
  LatLng? _currentLocation;
  bool _isLocating = false;
  bool _hasTileError = false;
  bool _mapReady = false;
  int _mapKey = 0;
  String? _locationMessage;

  List<List<LatLng>> get _routeLines => [
    for (final route in widget.routes)
      if (route.points.length >= 2)
        [
          for (final point in route.points)
            LatLng(point.latitude, point.longitude),
        ],
  ];

  List<LatLng> get _routePoints => [
    for (final line in _routeLines)
      for (final point in line) point,
  ];

  @override
  void didUpdateWidget(covariant ExploreMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routes != widget.routes && _currentLocation == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoutes());
    }
    if (oldWidget.currentLocation != widget.currentLocation &&
        widget.followLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _followCurrentLocation();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final routePoints = _routePoints;
    final hasRoute = routePoints.length >= 2;
    final currentLocation = widget.currentLocation ?? _currentLocation;
    final center = currentLocation ?? _defaultCenter;
    final hasTrack = widget.trackPoints.length >= 2;

    return Semantics(
      label: 'Peta OpenStreetMap untuk eksplorasi dan sesi aktif',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: SizedBox(
          height: widget.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FlutterMap(
                key: ValueKey(_mapKey),
                options: MapOptions(
                  initialCenter: center,
                  initialCameraFit: hasRoute && _currentLocation == null
                      ? CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(routePoints),
                          padding: const EdgeInsets.all(44),
                        )
                      : null,
                  initialZoom: widget.followLocation && currentLocation != null
                      ? 16
                      : 12,
                  minZoom: 3,
                  maxZoom: 18,
                  backgroundColor: colors.surfaceContainerHighest,
                  onMapReady: () {
                    _mapReady = true;
                    _fitRoutes();
                    _followCurrentLocation();
                  },
                ),
                mapController: _mapController,
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
                  if (hasRoute)
                    PolylineLayer(
                      polylines: [
                        for (final line in _routeLines)
                          Polyline(
                            points: line,
                            strokeWidth: 5,
                            color: SenapathColors.sky,
                          ),
                      ],
                    ),
                  if (hasTrack)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: widget.trackPoints,
                          strokeWidth: 7,
                          color: SenapathColors.coral,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      for (final line in _routeLines)
                        Marker(
                          point: line.first,
                          width: 34,
                          height: 38,
                          child: Icon(
                            Icons.trip_origin,
                            color: SenapathColors.spring,
                            size: 30,
                          ),
                        ),
                      for (final line in _routeLines)
                        Marker(
                          point: line.last,
                          width: 34,
                          height: 38,
                          child: Icon(
                            Icons.flag_rounded,
                            color: SenapathColors.gold,
                            size: 30,
                          ),
                        ),
                      if (currentLocation case final location?)
                        Marker(
                          point: location,
                          width: 38,
                          height: 38,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: SenapathColors.ink,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.surface,
                                width: 3,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.navigation_rounded,
                              size: 19,
                              color: SenapathColors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        '© OpenStreetMap contributors',
                        onTap: () => launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      border: Border.all(color: colors.outline, width: 2),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: _MapStatusBadge(
                  icon: _hasTileError ? Icons.cloud_off : Icons.public,
                  label: _hasTileError
                      ? 'Peta online tidak tersedia'
                      : 'OpenStreetMap',
                  isError: _hasTileError,
                ),
              ),
              if (widget.showLocationButton)
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    tooltip: 'Tampilkan lokasi saya',
                    onPressed: _isLocating ? null : _showCurrentLocation,
                    icon: _isLocating
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),
              if (widget.showEmptyMessage &&
                  !hasRoute &&
                  !hasTrack &&
                  currentLocation == null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Material(
                    color: colors.surface.withValues(alpha: 0.94),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(color: colors.outline, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.explore_outlined, color: colors.primary),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Jelajahi area sekitar, atau mulai sesi untuk '
                              'merekam jejak GPS dan memilih rute.',
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_locationMessage != null)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 56,
                  child: Material(
                    color: colors.errorContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(color: colors.outline, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        _locationMessage!,
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),
                  ),
                ),
              if (_hasTileError)
                Positioned(
                  right: 10,
                  bottom: hasRoute || _currentLocation != null ? 10 : 76,
                  child: IconButton(
                    tooltip: 'Muat ulang peta',
                    onPressed: () => setState(() {
                      _hasTileError = false;
                      _mapKey++;
                      _mapController = MapController();
                    }),
                    icon: const Icon(Icons.refresh),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _locationMessage = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(
            () => _locationMessage = 'Aktifkan layanan lokasi perangkat.',
          );
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(
            () => _locationMessage =
                'Izin lokasi belum tersedia. Peta tetap bisa digunakan.',
          );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(
        () => _currentLocation = LatLng(position.latitude, position.longitude),
      );
      _mapController.move(LatLng(position.latitude, position.longitude), 14);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _locationMessage = 'Lokasi belum berhasil didapat. Coba lagi di area dengan sinyal GPS.',
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _fitRoutes() {
    final points = _routePoints;
    if (!mounted || points.length < 2) return;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  void _followCurrentLocation() {
    final location = widget.currentLocation ?? _currentLocation;
    if (!_mapReady || !widget.followLocation || location == null) return;
    _mapController.move(location, 16);
  }
}

class _MapStatusBadge extends StatelessWidget {
  const _MapStatusBadge({
    required this.icon,
    required this.label,
    required this.isError,
  });

  final IconData icon;
  final String label;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: isError ? colors.errorContainer : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: colors.outline, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isError ? colors.onErrorContainer : colors.primary,
            ),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
