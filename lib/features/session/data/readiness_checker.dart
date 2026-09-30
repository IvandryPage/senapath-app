import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ReadinessReport {
  const ReadinessReport({
    required this.locationPermissionGranted,
    required this.locationPermanentlyDenied,
    required this.locationServicesEnabled,
    required this.gpsFixAvailable,
    required this.accelerometerAvailable,
    required this.gyroscopeAvailable,
    required this.notificationsGranted,
    this.gpsAccuracyMeters,
  });

  final bool locationPermissionGranted;
  final bool locationPermanentlyDenied;
  final bool locationServicesEnabled;
  final bool gpsFixAvailable;
  final bool accelerometerAvailable;
  final bool gyroscopeAvailable;
  final bool notificationsGranted;
  final double? gpsAccuracyMeters;

  bool get canStartRecording => locationPermissionGranted;

  bool get hasLimitedMetrics =>
      !locationServicesEnabled ||
      !gpsFixAvailable ||
      !accelerometerAvailable ||
      !gyroscopeAvailable;
}

abstract interface class ReadinessChecker {
  Future<ReadinessReport> check({bool requestLocationPermission = false});
  Future<bool> openLocationSettings();
}

class DeviceReadinessChecker implements ReadinessChecker {
  const DeviceReadinessChecker();

  @override
  Future<ReadinessReport> check({
    bool requestLocationPermission = false,
  }) async {
    var permission = await Geolocator.checkPermission();
    if (requestLocationPermission &&
        (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever)) {
      permission = await Geolocator.requestPermission();
    }
    final locationPermissionGranted =
        permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
    final locationPermanentlyDenied =
        permission == LocationPermission.deniedForever;
    final locationServicesEnabled = await Geolocator.isLocationServiceEnabled();

    Position? position;
    if (locationPermissionGranted && locationServicesEnabled) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {
        position = null;
      }
    }

    final sensorAvailability = await Future.wait([
      _hasSensorEvent(accelerometerEventStream()),
      _hasSensorEvent(gyroscopeEventStream()),
    ]);
    final notificationStatus = await Permission.notification.status;

    return ReadinessReport(
      locationPermissionGranted: locationPermissionGranted,
      locationPermanentlyDenied: locationPermanentlyDenied,
      locationServicesEnabled: locationServicesEnabled,
      gpsFixAvailable: position != null,
      accelerometerAvailable: sensorAvailability[0],
      gyroscopeAvailable: sensorAvailability[1],
      notificationsGranted: notificationStatus.isGranted,
      gpsAccuracyMeters: position?.accuracy,
    );
  }

  @override
  Future<bool> openLocationSettings() => Geolocator.openAppSettings();

  Future<bool> _hasSensorEvent<T>(Stream<T> stream) async {
    try {
      await stream.first.timeout(const Duration(seconds: 2));
      return true;
    } catch (_) {
      return false;
    }
  }
}

abstract interface class LocationSource {
  Stream<Position> get positions;
}

class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource();

  @override
  Stream<Position> get positions => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    ),
  );
}

abstract interface class BarometerSource {
  Stream<double> get pressureHpa;
}

abstract interface class MotionSensorSource {
  Stream<AccelerometerEvent> get accelerometerReadings;
  Stream<GyroscopeEvent> get gyroscopeReadings;
}

class SensorsPlusMotionSensorSource implements MotionSensorSource {
  const SensorsPlusMotionSensorSource();

  @override
  Stream<AccelerometerEvent> get accelerometerReadings =>
      accelerometerEventStream();

  @override
  Stream<GyroscopeEvent> get gyroscopeReadings => gyroscopeEventStream();
}

class SensorsPlusBarometerSource implements BarometerSource {
  const SensorsPlusBarometerSource();

  @override
  Stream<double> get pressureHpa =>
      barometerEventStream().map((event) => event.pressure);
}
