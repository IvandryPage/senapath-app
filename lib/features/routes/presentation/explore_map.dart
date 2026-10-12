import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
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
    this.movementBearingDegrees,
    this.northUpLocked = false,
    this.onToggleNorthUp,
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
  final double? movementBearingDegrees;
  final bool northUpLocked;
  final VoidCallback? onToggleNorthUp;
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
  bool _openDeviceLocationSettings = false;
  bool _openAppLocationSettings = false;
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
    if (oldWidget.movementBearingDegrees != widget.movementBearingDegrees) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyMovementBearing();
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
                  initialRotation: widget.movementBearingDegrees == null
                      ? 0
                      : widget.movementBearingDegrees!,
                  minZoom: 3,
                  maxZoom: 18,
                  backgroundColor: colors.surfaceContainerHighest,
                  onMapReady: () {
                    _mapReady = true;
                    _fitRoutes();
                    _followCurrentLocation();
                    _applyMovementBearing();
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
                            color: SenapathColors.accent,
                          ),
                      ],
                    ),
                  if (hasTrack)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: widget.trackPoints,
                          strokeWidth: 7,
                          color: SenapathColors.blue,
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
                            color: SenapathColors.blue,
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
                            color: SenapathColors.accent,
                            size: 30,
                          ),
                        ),
                      for (final route in widget.routes)
                        for (final checkpoint in route.checkpoints)
                          Marker(
                            point: LatLng(
                              checkpoint.latitude,
                              checkpoint.longitude,
                            ),
                            width: 42,
                            height: 46,
                            child: Tooltip(
                              message: checkpoint.name,
                              child: const Icon(
                                Icons.flag_circle,
                                color: SenapathColors.navy,
                                size: 34,
                              ),
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
                    alignment: AttributionAlignment.bottomLeft,
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
              if (_hasTileError)
                const Positioned(
                  top: 64,
                  left: 12,
                  child: _MapStatusBadge(
                    icon: Icons.cloud_off,
                    label: 'Peta online tidak tersedia',
                    isError: true,
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
              const Positioned(top: 58, right: 10, child: _CompassIndicator()),
              if (widget.onToggleNorthUp != null)
                Positioned(
                  top: 122,
                  right: 10,
                  child: IconButton.filledTonal(
                    tooltip: widget.northUpLocked
                        ? 'Ikuti arah gerak'
                        : 'Kunci arah utara',
                    onPressed: widget.onToggleNorthUp,
                    icon: Icon(
                      widget.northUpLocked
                          ? Icons.explore_outlined
                          : Icons.navigation_rounded,
                    ),
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
              if (_openDeviceLocationSettings || _openAppLocationSettings)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 108,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _openDeviceLocationSettings
                          ? Geolocator.openLocationSettings
                          : Geolocator.openAppSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Pengaturan lokasi'),
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
      _openDeviceLocationSettings = false;
      _openAppLocationSettings = false;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() {
            _locationMessage = 'Aktifkan layanan lokasi perangkat.';
            _openDeviceLocationSettings = true;
          });
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
          setState(() {
            _locationMessage =
                'Izin lokasi belum tersedia. Peta tetap bisa digunakan.';
            _openAppLocationSettings =
                permission == LocationPermission.deniedForever;
          });
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
    } on TimeoutException {
      if (!mounted) return;
      setState(
        () => _locationMessage =
            'Belum mendapat fix GPS setelah 15 detik. Coba lagi di luar '
            'ruangan dengan pandangan langit terbuka.',
      );
    } on LocationServiceDisabledException {
      if (!mounted) return;
      setState(() {
        _locationMessage = 'Aktifkan layanan lokasi perangkat.';
        _openDeviceLocationSettings = true;
      });
    } on PermissionDeniedException {
      if (!mounted) return;
      setState(() {
        _locationMessage =
            'Izin lokasi dicabut. Izinkan kembali di pengaturan aplikasi.';
        _openAppLocationSettings = true;
      });
    } on Exception {
      if (!mounted) return;
      setState(
        () => _locationMessage =
            'Perangkat gagal memberikan lokasi. Periksa izin dan pengaturan '
            'akurasi lokasi, lalu coba lagi.',
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

  void _applyMovementBearing() {
    if (!_mapReady) return;
    _mapController.rotate(widget.movementBearingDegrees ?? 0);
  }
}

class _CompassIndicator extends StatelessWidget {
  const _CompassIndicator();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        final heading = snapshot.data?.heading;
        final hasHeading = heading != null && heading.isFinite;
        final colors = Theme.of(context).colorScheme;
        final description = hasHeading
            ? 'Kompas utara, perangkat menghadap ${heading.toStringAsFixed(0)}°'
            : 'Kompas utara tidak tersedia';

        return Tooltip(
          message: description,
          child: Semantics(
            label: description,
            child: ExcludeSemantics(
              child: Container(
                width: 48,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.96),
                  border: Border.all(color: colors.outline),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22000000), blurRadius: 6),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.rotate(
                      angle: hasHeading ? -heading * math.pi / 180 : 0,
                      child: Icon(
                        hasHeading
                            ? Icons.navigation_rounded
                            : Icons.explore_outlined,
                        color: hasHeading
                            ? colors.error
                            : colors.onSurfaceVariant,
                        size: 26,
                      ),
                    ),
                    Text(
                      hasHeading ? 'N' : '—',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
