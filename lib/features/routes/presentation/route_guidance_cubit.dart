import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/saved_route.dart';

class RoutePosition {
  /// Membuat posisi perangkat beserta tingkat akurasinya.
  const RoutePosition({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}

abstract interface class RoutePositionSource {
  /// Meminta izin lokasi dan mengembalikan status diterima.
  Future<bool> requestPermission();

  /// Mengalirkan pembaruan posisi perangkat.
  Stream<RoutePosition> watch();
}

class GeolocatorRoutePositionSource implements RoutePositionSource {
  /// Membuat sumber posisi berbasis Geolocator.
  const GeolocatorRoutePositionSource();

  /// Memeriksa layanan lokasi dan meminta izin yang diperlukan.
  @override
  Future<bool> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Mengirim posisi awal lalu melanjutkan dengan aliran posisi terkini.
  @override
  Stream<RoutePosition> watch() async* {
    try {
      final first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      yield _toRoutePosition(first);
    } catch (_) {}
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).map(_toRoutePosition);
  }

  /// Mengubah posisi Geolocator menjadi [RoutePosition].
  RoutePosition _toRoutePosition(Position position) => RoutePosition(
    latitude: position.latitude,
    longitude: position.longitude,
    accuracyMeters: position.accuracy,
  );
}

class RouteGuidanceState {
  /// Membuat status panduan rute berisi posisi dan progres.
  const RouteGuidanceState({
    this.route,
    this.currentPosition,
    this.nearestRouteIndex = 0,
    this.distanceToRouteMeters,
    this.distanceRemainingMeters,
    this.isStarting = false,
    this.isRunning = false,
    this.hasReachedEnd = false,
    this.error,
  });

  final RouteRecord? route;
  final RoutePosition? currentPosition;
  final int nearestRouteIndex;
  final double? distanceToRouteMeters;
  final double? distanceRemainingMeters;
  final bool isStarting;
  final bool isRunning;
  final bool hasReachedEnd;
  final String? error;

  /// Menandakan posisi saat ini cukup akurat untuk panduan.
  bool get hasAccurateFix =>
      currentPosition != null && currentPosition!.accuracyMeters <= 80;

  /// Menandakan posisi berada di luar toleransi jalur rute.
  bool get isOffRoute =>
      hasAccurateFix &&
      distanceToRouteMeters != null &&
      distanceToRouteMeters! >
          math.max(35, currentPosition!.accuracyMeters * 2);

  /// Menyalin status dengan nilai baru dan opsi pengosongan posisi atau galat.
  RouteGuidanceState copyWith({
    RouteRecord? route,
    RoutePosition? currentPosition,
    int? nearestRouteIndex,
    double? distanceToRouteMeters,
    double? distanceRemainingMeters,
    bool? isStarting,
    bool? isRunning,
    bool? hasReachedEnd,
    String? error,
    bool clearCurrentPosition = false,
    bool clearError = false,
  }) => RouteGuidanceState(
    route: route ?? this.route,
    currentPosition: clearCurrentPosition
        ? null
        : currentPosition ?? this.currentPosition,
    nearestRouteIndex: nearestRouteIndex ?? this.nearestRouteIndex,
    distanceToRouteMeters: distanceToRouteMeters ?? this.distanceToRouteMeters,
    distanceRemainingMeters:
        distanceRemainingMeters ?? this.distanceRemainingMeters,
    isStarting: isStarting ?? this.isStarting,
    isRunning: isRunning ?? this.isRunning,
    hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
    error: clearError ? null : error ?? this.error,
  );
}

class RouteGuidanceCubit extends Cubit<RouteGuidanceState> {
  /// Membuat cubit panduan dengan sumber posisi [RoutePositionSource].
  RouteGuidanceCubit(this._positionSource) : super(const RouteGuidanceState());

  final RoutePositionSource _positionSource;
  StreamSubscription<RoutePosition>? _positionSubscription;
  List<double> _distanceRemainingByIndex = const [];

  /// Meminta izin lokasi dan mulai mengikuti [route].
  Future<void> start(RouteRecord route) async {
    if (state.isStarting || state.isRunning) return;
    if (route.points.length < 2) {
      emit(
        state.copyWith(
          route: route,
          error: 'Rute ini tidak memiliki geometri untuk diikuti.',
        ),
      );
      return;
    }

    emit(RouteGuidanceState(route: route, isStarting: true));
    try {
      if (!await _positionSource.requestPermission()) {
        emit(
          RouteGuidanceState(
            route: route,
            error: 'Izin lokasi belum aktif. Panduan rute tidak dapat dimulai.',
          ),
        );
        return;
      }

      _prepareRemainingDistances(route.points);
      _positionSubscription = _positionSource.watch().listen(
        _onPosition,
        onError: (_) => emit(
          state.copyWith(
            isRunning: false,
            error: 'Lokasi tidak terbaca. Periksa izin dan pengaturan lokasi ponsel.',
          ),
        ),
      );
      emit(
        state.copyWith(isStarting: false, isRunning: true, clearError: true),
      );
    } catch (_) {
      emit(
        RouteGuidanceState(
          route: route,
          error: 'Panduan rute tidak dapat dimulai. Periksa pengaturan lokasi ponsel.',
        ),
      );
    }
  }

  /// Menghitung sisa jarak dari setiap titik rute sampai titik akhir.
  void _prepareRemainingDistances(List<RoutePoint> points) {
    _distanceRemainingByIndex = List<double>.filled(points.length, 0);
    for (var index = points.length - 2; index >= 0; index--) {
      _distanceRemainingByIndex[index] =
          _distanceRemainingByIndex[index + 1] +
          _distanceBetween(points[index], points[index + 1]);
    }
  }

  /// Memperbarui titik terdekat, sisa jarak, dan status akhir rute.
  void _onPosition(RoutePosition position) {
    final route = state.route;
    if (route == null || route.points.isEmpty) return;
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < route.points.length; index++) {
      final distance = _distanceToPosition(position, route.points[index]);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }
    nearestIndex = math.max(state.nearestRouteIndex, nearestIndex);
    emit(
      state.copyWith(
        currentPosition: position,
        nearestRouteIndex: nearestIndex,
        distanceToRouteMeters: nearestDistance,
        distanceRemainingMeters: _distanceRemainingByIndex[nearestIndex],
        hasReachedEnd:
            nearestIndex == route.points.length - 1 && nearestDistance <= 40,
        clearError: true,
      ),
    );
  }

  /// Menghitung jarak meter antara posisi perangkat dan satu titik rute.
  double _distanceToPosition(RoutePosition position, RoutePoint point) =>
      Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        point.latitude,
        point.longitude,
      );

  /// Menghitung jarak meter antara dua titik rute.
  double _distanceBetween(RoutePoint first, RoutePoint second) =>
      Geolocator.distanceBetween(
        first.latitude,
        first.longitude,
        second.latitude,
        second.longitude,
      );

  /// Menghentikan langganan posisi dan menandai panduan tidak berjalan.
  Future<void> stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (!isClosed) emit(state.copyWith(isRunning: false, isStarting: false));
  }

  /// Membatalkan langganan posisi sebelum menutup cubit.
  @override
  Future<void> close() async {
    await _positionSubscription?.cancel();
    return super.close();
  }
}
