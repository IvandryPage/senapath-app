import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:latlong2/latlong.dart' as latlong;

import '../domain/saved_route.dart';

class GoogleDirectionsMap extends StatefulWidget {
  const GoogleDirectionsMap({
    required this.route,
    this.currentPosition,
    this.trackPoints = const [],
    this.followCurrentPosition = false,
    this.height,
    super.key,
  });

  final RouteRecord route;
  final RoutePoint? currentPosition;
  final List<latlong.LatLng> trackPoints;
  final bool followCurrentPosition;
  final double? height;

  @override
  State<GoogleDirectionsMap> createState() => _GoogleDirectionsMapState();
}

class _GoogleDirectionsMapState extends State<GoogleDirectionsMap> {
  maps.GoogleMapController? _controller;

  @override
  void didUpdateWidget(covariant GoogleDirectionsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route.points != widget.route.points) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoute());
    }
    if (oldWidget.currentPosition != widget.currentPosition &&
        widget.followCurrentPosition) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _followPosition());
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.route.points
        .map((point) => maps.LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    final initialPoint = points.isEmpty
        ? const maps.LatLng(-7.7956, 110.3695)
        : points.first;
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          maps.GoogleMap(
            initialCameraPosition: maps.CameraPosition(
              target: initialPoint,
              zoom: 13,
            ),
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _controller = controller;
              if (widget.followCurrentPosition) {
                _followPosition();
              } else {
                _fitRoute();
              }
            },
            polylines: {
              if (points.length >= 2)
                maps.Polyline(
                  polylineId: const maps.PolylineId('cycling-route'),
                  points: points,
                  color: Theme.of(context).colorScheme.primary,
                  width: 6,
                ),
              if (widget.trackPoints.length >= 2)
                maps.Polyline(
                  polylineId: const maps.PolylineId('recorded-track'),
                  points: [
                    for (final point in widget.trackPoints)
                      maps.LatLng(point.latitude, point.longitude),
                  ],
                  color: Theme.of(context).colorScheme.tertiary,
                  width: 6,
                ),
            },
            markers: {
              if (points.isNotEmpty)
                maps.Marker(
                  markerId: const maps.MarkerId('route-origin'),
                  position: points.first,
                  infoWindow: const maps.InfoWindow(title: 'Mulai'),
                ),
              if (points.length >= 2)
                maps.Marker(
                  markerId: const maps.MarkerId('route-destination'),
                  position: points.last,
                  infoWindow: maps.InfoWindow(title: widget.route.name),
                ),
              if (widget.currentPosition case final current?)
                maps.Marker(
                  markerId: const maps.MarkerId('current-position'),
                  position: maps.LatLng(current.latitude, current.longitude),
                  icon: maps.BitmapDescriptor.defaultMarkerWithHue(
                    maps.BitmapDescriptor.hueAzure,
                  ),
                  infoWindow: const maps.InfoWindow(title: 'Lokasi saya'),
                ),
            },
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              heroTag: 'google-route-recenter-${widget.route.id}',
              tooltip: 'Tampilkan seluruh rute',
              onPressed: _fitRoute,
              child: const Icon(Icons.center_focus_strong),
            ),
          ),
        ],
      ),
    );
  }

  void _fitRoute() {
    final controller = _controller;
    final points = widget.route.points;
    if (controller == null || points.length < 2) return;
    final latitudes = points.map((point) => point.latitude);
    final longitudes = points.map((point) => point.longitude);
    var south = latitudes.reduce((a, b) => a < b ? a : b);
    var north = points
        .map((point) => point.latitude)
        .reduce((a, b) => a > b ? a : b);
    var west = longitudes.reduce((a, b) => a < b ? a : b);
    var east = points
        .map((point) => point.longitude)
        .reduce((a, b) => a > b ? a : b);
    if (south == north) {
      south -= 0.0001;
      north += 0.0001;
    }
    if (west == east) {
      west -= 0.0001;
      east += 0.0001;
    }
    controller.animateCamera(
      maps.CameraUpdate.newLatLngBounds(
        maps.LatLngBounds(
          southwest: maps.LatLng(south, west),
          northeast: maps.LatLng(north, east),
        ),
        48,
      ),
    );
  }

  void _followPosition() {
    final controller = _controller;
    final position = widget.currentPosition;
    if (controller == null || position == null) return;
    controller.animateCamera(
      maps.CameraUpdate.newCameraPosition(
        maps.CameraPosition(
          target: maps.LatLng(position.latitude, position.longitude),
          zoom: 16,
        ),
      ),
    );
  }
}
