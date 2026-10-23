import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Laporan kesiapan perangkat untuk merekam sesi.
class ReadinessReport {
  /// Membuat laporan kesiapan.
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

  /// Menentukan apakah bisa mulai merekam.
  bool get canStartRecording =>
      locationPermissionGranted && locationServicesEnabled;

  /// Menentukan apakah metrik terbatas.
  bool get hasLimitedMetrics =>
      !locationServicesEnabled ||
      !gpsFixAvailable ||
      !accelerometerAvailable ||
      !gyroscopeAvailable;
}

/// Antarmuka pemeriksa kesiapan perangkat.
abstract interface class ReadinessChecker {
  /// Memeriksa kesiapan perangkat.
  Future<ReadinessReport> check({
    bool requestLocationPermission = false,
    bool requestNotificationPermission = false,
    bool checkGpsFix = false,
  });
  /// Membuka pengaturan lokasi aplikasi.
  Future<bool> openLocationSettings();
  /// Membuka pengaturan layanan lokasi.
  Future<bool> openLocationServiceSettings();
  /// Membuka pengaturan notifikasi aplikasi.
  Future<bool> openNotificationSettings();
}

/// Pemeriksa kesiapan berbasis perangkat.
class DeviceReadinessChecker implements ReadinessChecker {
  /// Membuat pemeriksa kesiapan perangkat.
  const DeviceReadinessChecker();

  @override
  /// Memeriksa izin, layanan, sensor, dan GPS.
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
  /// Membuka pengaturan aplikasi untuk lokasi.
  Future<bool> openLocationSettings() => Geolocator.openAppSettings();

  @override
  /// Membuka pengaturan layanan lokasi sistem.
  Future<bool> openLocationServiceSettings() =>
      Geolocator.openLocationSettings();

  @override
  /// Membuka pengaturan aplikasi untuk notifikasi.
  Future<bool> openNotificationSettings() => openAppSettings();

  /// Memeriksa ketersediaan sensor dengan menunggu event pertama.
  Future<bool> _hasSensorEvent<T>(Stream<T> stream) async {
    try {
      await stream.first.timeout(const Duration(seconds: 2));
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Sumber posisi lokasi.
abstract interface class LocationSource {
  /// Aliran posisi lokasi.
  Stream<Position> get positions;
}

/// Sumber lokasi berbasis Geolocator.
class GeolocatorLocationSource implements LocationSource {
  /// Membuat sumber lokasi Geolocator.
  const GeolocatorLocationSource();

  @override
  /// Menghasilkan aliran posisi sesuai platform.
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

/// Sumber tekanan barometer.
abstract interface class BarometerSource {
  /// Aliran tekanan udara dalam hPa.
  Stream<double> get pressureHpa;
}

/// Sumber sensor gerakan.
abstract interface class MotionSensorSource {
  /// Aliran pembacaan akselerometer.
  Stream<AccelerometerEvent> get accelerometerReadings;
  /// Aliran pembacaan giroskop.
  Stream<GyroscopeEvent> get gyroscopeReadings;
}

/// Sumber sensor gerakan berbasis sensors_plus.
class SensorsPlusMotionSensorSource implements MotionSensorSource {
  /// Membuat sumber sensor gerakan.
  const SensorsPlusMotionSensorSource();

  @override
  /// Mengambil aliran akselerometer.
  Stream<AccelerometerEvent> get accelerometerReadings =>
      accelerometerEventStream();

  @override
  /// Mengambil aliran giroskop.
  Stream<GyroscopeEvent> get gyroscopeReadings => gyroscopeEventStream();
}

/// Sumber barometer berbasis sensors_plus.
class SensorsPlusBarometerSource implements BarometerSource {
  /// Membuat sumber barometer.
  const SensorsPlusBarometerSource();

  @override
  /// Mengambil aliran tekanan barometer.
  Stream<double> get pressureHpa =>
      barometerEventStream().map((event) => event.pressure);
}
