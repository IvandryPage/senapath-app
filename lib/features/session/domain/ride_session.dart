import 'dart:math' as math;

enum RideSessionStatus { recording, paused, completed }

enum RideActivityType { ride, commute, training, race }

class RideSessionSnapshot {
  /// Membuat snapshot sesi berkendara.
  const RideSessionSnapshot({
    required this.id,
    this.title = '',
    this.activityType = RideActivityType.ride,
    this.source = 'recorded',
    required this.startedAt,
    required this.status,
    required this.totalPausedMilliseconds,
    required this.distanceMeters,
    required this.currentSpeedMetersPerSecond,
    this.syncStatus = 'pending',
    this.endedAt,
    this.pausedAt,
    this.gpsAccuracyMeters,
  });

  final String id;
  final String title;
  final RideActivityType activityType;
  final String source;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime? pausedAt;
  final RideSessionStatus status;
  final int totalPausedMilliseconds;
  final double distanceMeters;
  final double currentSpeedMetersPerSecond;
  final String syncStatus;
  final double? gpsAccuracyMeters;

  /// Menghitung durasi sesi hingga waktu tertentu dengan memperhitungkan jeda.
  Duration durationAt(DateTime now) {
    final end = endedAt ?? now;
    final currentlyPaused =
        status == RideSessionStatus.paused && pausedAt != null
        ? end.difference(pausedAt!).inMilliseconds
        : 0;
    final elapsed =
        end.difference(startedAt).inMilliseconds -
        totalPausedMilliseconds -
        currentlyPaused;
    return Duration(milliseconds: elapsed.clamp(0, 1 << 62));
  }
}

class TelemetryLocation {
  /// Membuat titik telemetri lokasi.
  const TelemetryLocation({
    required this.recordedAt,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.altitudeMeters,
    this.altitudeAccuracyMeters,
    this.barometricPressureHpa,
    this.accelerationMagnitudeMetersPerSecondSquared,
    this.rotationRateMagnitudeRadiansPerSecond,
    required this.speedMetersPerSecond,
  });

  final DateTime recordedAt;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double altitudeMeters;
  final double? altitudeAccuracyMeters;
  final double? barometricPressureHpa;
  final double? accelerationMagnitudeMetersPerSecondSquared;
  final double? rotationRateMagnitudeRadiansPerSecond;
  final double speedMetersPerSecond;

  /// Mengonversi lokasi telemetri ke bentuk JSON.
  Map<String, Object?> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracyMeters': accuracyMeters,
    'altitudeMeters': altitudeMeters,
    'altitudeAccuracyMeters': altitudeAccuracyMeters,
    'barometricPressureHpa': barometricPressureHpa,
    'accelerationMagnitudeMetersPerSecondSquared':
        accelerationMagnitudeMetersPerSecondSquared,
    'rotationRateMagnitudeRadiansPerSecond':
        rotationRateMagnitudeRadiansPerSecond,
    'speedMetersPerSecond': speedMetersPerSecond,
  };

  /// Membuat lokasi telemetri dari data JSON.
  factory TelemetryLocation.fromJson(
    Map<String, dynamic> json, {
    required DateTime recordedAt,
  }) => TelemetryLocation(
    recordedAt: recordedAt,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    accuracyMeters: (json['accuracyMeters'] as num).toDouble(),
    altitudeMeters: (json['altitudeMeters'] as num).toDouble(),
    altitudeAccuracyMeters: (json['altitudeAccuracyMeters'] as num?)
        ?.toDouble(),
    barometricPressureHpa: (json['barometricPressureHpa'] as num?)?.toDouble(),
    accelerationMagnitudeMetersPerSecondSquared:
        (json['accelerationMagnitudeMetersPerSecondSquared'] as num?)
            ?.toDouble(),
    rotationRateMagnitudeRadiansPerSecond:
        (json['rotationRateMagnitudeRadiansPerSecond'] as num?)?.toDouble(),
    speedMetersPerSecond: (json['speedMetersPerSecond'] as num).toDouble(),
  );
}

class MotionSnapshot {
  /// Membuat snapshot data gerakan dan irama.
  const MotionSnapshot({
    this.accelerationMagnitude,
    this.rotationRateMagnitude,
    this.cadenceRpm,
    this.accelerationHistory = const [],
    this.rotationHistory = const [],
    this.cadenceHistory = const [],
  });

  final double? accelerationMagnitude;
  final double? rotationRateMagnitude;
  final double? cadenceRpm;
  final List<double> accelerationHistory;
  final List<double> rotationHistory;
  final List<double> cadenceHistory;

  /// Menentukan apakah snapshot gerakan memiliki data.
  bool get hasData =>
      accelerationMagnitude != null ||
      rotationRateMagnitude != null ||
      accelerationHistory.isNotEmpty ||
      rotationHistory.isNotEmpty;

  /// Menentukan apakah grafik akselerasi tersedia.
  bool get hasAccelerationGraph => accelerationHistory.length >= 2;

  /// Menentukan apakah grafik rotasi tersedia.
  bool get hasRotationGraph => rotationHistory.length >= 2;

  /// Menentukan apakah grafik irama tersedia.
  bool get hasCadenceGraph => cadenceHistory.length >= 2;

  /// Menghitung puncak akselerasi.
  double? get peakAcceleration =>
      accelerationHistory.isEmpty ? null : accelerationHistory.reduce(math.max);

  /// Menghitung puncak rotasi.
  double? get peakRotation =>
      rotationHistory.isEmpty ? null : rotationHistory.reduce(math.max);
}

class RideSpeedSample {
  /// Membuat sampel kecepatan pada waktu tertentu.
  const RideSpeedSample({
    required this.recordedAt,
    required this.speedMetersPerSecond,
  });

  final DateTime recordedAt;
  final double speedMetersPerSecond;
}

class RideSessionSummary {
  /// Membuat ringkasan sesi beserta data performa.
  const RideSessionSummary({
    required this.session,
    required this.sampleCount,
    required this.speedSamples,
    required this.elevationSource,
    this.accelerometerSampleCount = 0,
    this.gyroscopeSampleCount = 0,
    this.elevationGainMeters,
  });

  final RideSessionSnapshot session;
  final int sampleCount;
  final List<RideSpeedSample> speedSamples;
  final double? elevationGainMeters;
  final String elevationSource;
  final int accelerometerSampleCount;
  final int gyroscopeSampleCount;

  /// Menentukan apakah grafik kecepatan tersedia.
  bool get hasSpeedGraph => speedSamples.length >= 5;

  /// Membuat salinan ringkasan dengan sesi yang diperbarui.
  RideSessionSummary copyWith({RideSessionSnapshot? session}) =>
      RideSessionSummary(
        session: session ?? this.session,
        sampleCount: sampleCount,
        speedSamples: speedSamples,
        elevationSource: elevationSource,
        accelerometerSampleCount: accelerometerSampleCount,
        gyroscopeSampleCount: gyroscopeSampleCount,
        elevationGainMeters: elevationGainMeters,
      );
}
