enum WorkoutTargetType { duration, distance }

class WorkoutInterval {
  const WorkoutInterval({
    required this.name,
    required this.targetType,
    required this.targetValue,
    this.isRecovery = false,
  });

  final String name;
  final WorkoutTargetType targetType;
  final int targetValue;
  final bool isRecovery;

  factory WorkoutInterval.create({
    required String name,
    required WorkoutTargetType targetType,
    required int targetValue,
    bool isRecovery = false,
  }) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || normalizedName.length > 40) {
      throw ArgumentError.value(name, 'name', 'Use 1–40 characters.');
    }
    if (targetValue <= 0 ||
        (targetType == WorkoutTargetType.duration && targetValue > 86400) ||
        (targetType == WorkoutTargetType.distance && targetValue > 1000000)) {
      throw ArgumentError.value(targetValue, 'targetValue', 'Invalid target.');
    }
    return WorkoutInterval(
      name: normalizedName,
      targetType: targetType,
      targetValue: targetValue,
      isRecovery: isRecovery,
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'targetType': targetType.name,
    'targetValue': targetValue,
    'isRecovery': isRecovery,
  };

  factory WorkoutInterval.fromJson(Map<String, dynamic> json) {
    final type = WorkoutTargetType.values.firstWhere(
      (value) => value.name == json['targetType'],
      orElse: () => throw const FormatException('Jenis interval tidak valid.'),
    );
    final value = json['targetValue'];
    if (value is! int) {
      throw const FormatException('Target interval tidak valid.');
    }
    try {
      return WorkoutInterval.create(
        name: json['name'] as String? ?? '',
        targetType: type,
        targetValue: value,
        isRecovery: json['isRecovery'] as bool? ?? false,
      );
    } on ArgumentError {
      throw const FormatException('Data interval tidak valid.');
    }
  }

  String get targetDescription => switch (targetType) {
    WorkoutTargetType.duration => '${targetValue}s',
    WorkoutTargetType.distance =>
      '${(targetValue / 1000).toStringAsFixed(2)} km',
  };
}

class IntervalWorkout {
  const IntervalWorkout({
    required this.id,
    required this.name,
    required this.intervals,
    this.audioCueEnabled = true,
    this.hapticCueEnabled = true,
    this.visualCueEnabled = true,
  });

  final String id;
  final String name;
  final List<WorkoutInterval> intervals;
  final bool audioCueEnabled;
  final bool hapticCueEnabled;
  final bool visualCueEnabled;

  static IntervalWorkout create({
    required String id,
    required String name,
    required List<WorkoutInterval> intervals,
    bool audioCueEnabled = true,
    bool hapticCueEnabled = true,
    bool visualCueEnabled = true,
  }) {
    final normalizedName = name.trim();
    if (id.isEmpty || normalizedName.isEmpty || normalizedName.length > 60) {
      throw ArgumentError('Workout needs an ID and a 1–60 character name.');
    }
    if (intervals.isEmpty || intervals.length > 30) {
      throw ArgumentError.value(
        intervals.length,
        'intervals',
        'A workout must have 1–30 intervals.',
      );
    }
    return IntervalWorkout(
      id: id,
      name: normalizedName,
      intervals: List.unmodifiable(intervals),
      audioCueEnabled: audioCueEnabled,
      hapticCueEnabled: hapticCueEnabled,
      visualCueEnabled: visualCueEnabled,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'intervals': intervals.map((interval) => interval.toJson()).toList(),
    'audioCueEnabled': audioCueEnabled,
    'hapticCueEnabled': hapticCueEnabled,
    'visualCueEnabled': visualCueEnabled,
  };

  factory IntervalWorkout.fromJson(Map<String, dynamic> json) {
    final intervals = json['intervals'];
    if (intervals is! List) {
      throw const FormatException('Daftar interval tidak valid.');
    }
    try {
      return IntervalWorkout.create(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        intervals: intervals
            .map((item) {
              if (item is! Map<String, dynamic>) {
                throw const FormatException('Data interval tidak valid.');
              }
              return WorkoutInterval.fromJson(item);
            })
            .toList(growable: false),
        audioCueEnabled: json['audioCueEnabled'] as bool? ?? true,
        hapticCueEnabled: json['hapticCueEnabled'] as bool? ?? true,
        visualCueEnabled: json['visualCueEnabled'] as bool? ?? true,
      );
    } on ArgumentError {
      throw const FormatException('Data workout tidak valid.');
    }
  }
}

class WorkoutCheckpoint {
  const WorkoutCheckpoint({
    required this.sessionId,
    required this.workoutId,
    required this.intervalIndex,
    required this.intervalStartElapsedSeconds,
    required this.intervalStartDistanceMeters,
  });

  final String sessionId;
  final String workoutId;
  final int intervalIndex;
  final int intervalStartElapsedSeconds;
  final double intervalStartDistanceMeters;

  Map<String, Object?> toJson() => {
    'sessionId': sessionId,
    'workoutId': workoutId,
    'intervalIndex': intervalIndex,
    'intervalStartElapsedSeconds': intervalStartElapsedSeconds,
    'intervalStartDistanceMeters': intervalStartDistanceMeters,
  };

  factory WorkoutCheckpoint.fromJson(Map<String, dynamic> json) =>
      WorkoutCheckpoint(
        sessionId: json['sessionId'] as String,
        workoutId: json['workoutId'] as String,
        intervalIndex: json['intervalIndex'] as int,
        intervalStartElapsedSeconds: json['intervalStartElapsedSeconds'] as int,
        intervalStartDistanceMeters:
            (json['intervalStartDistanceMeters'] as num).toDouble(),
      );
}

class WorkoutIntervalProgress {
  const WorkoutIntervalProgress({
    required this.interval,
    required this.index,
    required this.total,
    required this.remainingValue,
    required this.isComplete,
  });

  final WorkoutInterval? interval;
  final int index;
  final int total;
  final double remainingValue;
  final bool isComplete;
}
