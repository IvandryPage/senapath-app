import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ReadinessReport {
  const ReadinessReport({
    required this.locationPermissionGranted,
    required this.backgroundLocationGranted,
    required this.locationPermanentlyDenied,
    required this.locationServicesEnabled,
    required this.gpsFixAvailable,
    required this.accelerometerAvailable,
    required this.gyroscopeAvailable,
    required this.notificationsGranted,
    required this.notificationsPermanentlyDenied,
    this.gpsAccuracyMeters,
    this.gpsFixChecked = false,
    this.gpsMessage,
  });

  final bool locationPermissionGranted;
  final bool backgroundLocationGranted;
  final bool locationPermanentlyDenied;
  final bool locationServicesEnabled;
  final bool gpsFixAvailable;
  final bool accelerometerAvailable;
  final bool gyroscopeAvailable;
  final bool notificationsGranted;
  final bool notificationsPermanentlyDenied;
  final double? gpsAccuracyMeters;
  final bool gpsFixChecked;
  final String? gpsMessage;

  bool get canStartRecording =>
      locationPermissionGranted && locationServicesEnabled;

  bool get hasLimitedMetrics =>
      !locationServicesEnabled ||
      !gpsFixAvailable ||
      !accelerometerAvailable ||
      !gyroscopeAvailable;
}

abstract interface class ReadinessChecker {
  Future<ReadinessReport> check({
    bool requestLocationPermission = false,
    bool requestNotificationPermission = false,
    bool checkGpsFix = false,
  });
  Future<bool> openLocationSettings();
  Future<bool> openLocationServiceSettings();
  Future<bool> openNotificationSettings();
}

class DeviceReadinessChecker implements ReadinessChecker {
  const DeviceReadinessChecker();

  @override
  Future<ReadinessReport> check({
    bool requestLocationPermission = false,
    bool requestNotificationPermission = false,
    bool checkGpsFix = false,
  }) async {
    var permission = await Geolocator.checkPermission();
    if (requestLocationPermission &&
        (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever)) {
      permission = await Geolocator.requestPermission();
    }
    if (requestLocationPermission &&
        permission == LocationPermission.whileInUse) {
      await Permission.locationAlways.request();
      permission = await Geolocator.checkPermission();
    }
    final locationPermissionGranted =
        permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
    final locationPermanentlyDenied =
        permission == LocationPermission.deniedForever;
    final locationServicesEnabled = await Geolocator.isLocationServiceEnabled();

    Position? position;
    String? gpsMessage;
    if (locationPermissionGranted && locationServicesEnabled && checkGpsFix) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } on TimeoutException {
        gpsMessage =
            'Belum mendapat fix GPS setelah 20 detik. Coba periksa di luar '
            'ruangan dengan pandangan langit terbuka.';
      } on LocationServiceDisabledException {
        gpsMessage = 'Layanan lokasi perangkat dimatikan.';
      } on PermissionDeniedException {
        gpsMessage = 'Izin lokasi dicabut. Izinkan kembali di pengaturan.';
      } on Exception {
        gpsMessage =
            'Perangkat gagal memberikan lokasi. Periksa izin dan pengaturan '
            'akurasi lokasi, lalu coba lagi.';
      }
    } else if (!locationServicesEnabled) {
      gpsMessage = 'Aktifkan layanan lokasi perangkat untuk mendapat fix GPS.';
    } else if (locationPermanentlyDenied) {
      gpsMessage = 'Izin lokasi ditolak permanen. Aktifkan izin dari pengaturan aplikasi.';
    } else if (!locationPermissionGranted) {
      gpsMessage = 'Izinkan akses lokasi agar Senapath dapat memeriksa GPS.';
    } else if (!checkGpsFix) {
      gpsMessage = 'GPS belum dicek. Tekan “Cek GPS sekarang” untuk mencoba.';
    }

    final sensorAvailability = await Future.wait([
      _hasSensorEvent(accelerometerEventStream()),
      _hasSensorEvent(gyroscopeEventStream()),
    ]);
    var notificationStatus = await Permission.notification.status;
    if (requestNotificationPermission && !notificationStatus.isGranted) {
      notificationStatus = await Permission.notification.request();
    }

    return ReadinessReport(
      locationPermissionGranted: locationPermissionGranted,
      backgroundLocationGranted: permission == LocationPermission.always,
      locationPermanentlyDenied: locationPermanentlyDenied,
      locationServicesEnabled: locationServicesEnabled,
      gpsFixAvailable: position != null,
      accelerometerAvailable: sensorAvailability[0],
      gyroscopeAvailable: sensorAvailability[1],
      notificationsGranted: notificationStatus.isGranted,
      notificationsPermanentlyDenied: notificationStatus.isPermanentlyDenied,
      gpsAccuracyMeters: position?.accuracy,
      gpsFixChecked:
          checkGpsFix && locationPermissionGranted && locationServicesEnabled,
      gpsMessage: gpsMessage,
    );
  }

  @override
  Future<bool> openLocationSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationServiceSettings() =>
      Geolocator.openLocationSettings();

  @override
  Future<bool> openNotificationSettings() => openAppSettings();

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
  Stream<Position> get positions {
    const accuracy = LocationAccuracy.high;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: accuracy,
          distanceFilter: 5,
          intervalDuration: const Duration(seconds: 5),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Senapath sedang merekam',
            notificationText: 'Lokasi dipakai untuk progres sesi bersepeda.',
            notificationChannelName: 'Perekaman sesi',
            notificationIcon: AndroidResource(name: 'notification_icon'),
            enableWakeLock: true,
          ),
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return Geolocator.getPositionStream(
        locationSettings: AppleSettings(
          accuracy: accuracy,
          distanceFilter: 5,
          activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: false,
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
        ),
      );
    }
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }
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
