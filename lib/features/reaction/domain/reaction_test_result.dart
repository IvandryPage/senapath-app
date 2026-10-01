class ReactionAttempt {
  const ReactionAttempt({required this.wasCorrect, this.reactionMilliseconds});

  final bool wasCorrect;
  final int? reactionMilliseconds;

  Map<String, Object?> toJson() => {
    'wasCorrect': wasCorrect,
    'reactionMilliseconds': reactionMilliseconds,
  };

  factory ReactionAttempt.fromJson(Map<String, Object?> json) {
    final wasCorrect = json['wasCorrect'];
    final rawMilliseconds = json['reactionMilliseconds'];
    final milliseconds = rawMilliseconds is num
        ? rawMilliseconds.toInt()
        : null;
    if (wasCorrect is! bool ||
        (wasCorrect && milliseconds == null) ||
        (milliseconds != null && milliseconds < 0)) {
      throw const FormatException('Invalid reaction attempt.');
    }
    return ReactionAttempt(
      wasCorrect: wasCorrect,
      reactionMilliseconds: milliseconds,
    );
  }
}

class ReactionTestResult {
  const ReactionTestResult({
    required this.id,
    required this.completedAt,
    required this.durationMilliseconds,
    required this.attempts,
  });

  final String id;
  final DateTime completedAt;
  final int durationMilliseconds;
  final List<ReactionAttempt> attempts;

  int get correctCount =>
      attempts.where((attempt) => attempt.wasCorrect).length;

  int get earlyCount => attempts.where((attempt) => !attempt.wasCorrect).length;

  int? get averageReactionMilliseconds {
    final reactionTimes = [
      for (final attempt in attempts)
        if (attempt.reactionMilliseconds != null) attempt.reactionMilliseconds!,
    ];
    if (reactionTimes.isEmpty) return null;
    return (reactionTimes.reduce((a, b) => a + b) / reactionTimes.length)
        .round();
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'completedAt': completedAt.toUtc().toIso8601String(),
    'durationMilliseconds': durationMilliseconds,
    'attempts': attempts.map((attempt) => attempt.toJson()).toList(),
  };

  factory ReactionTestResult.fromJson(Map<String, Object?> json) {
    final completedAtValue = json['completedAt'];
    final duration = json['durationMilliseconds'];
    final rawAttempts = json['attempts'];
    final completedAt = completedAtValue is String
        ? DateTime.tryParse(completedAtValue)
        : null;
    if (json['id'] is! String ||
        completedAt == null ||
        duration is! num ||
        duration <= 0 ||
        rawAttempts is! List) {
      throw const FormatException('Invalid reaction-test result.');
    }
    return ReactionTestResult(
      id: json['id'] as String,
      completedAt: completedAt.toUtc(),
      durationMilliseconds: duration.toInt(),
      attempts: [
        for (final rawAttempt in rawAttempts)
          if (rawAttempt is Map)
            ReactionAttempt.fromJson(Map<String, Object?>.from(rawAttempt))
          else
            throw const FormatException('Invalid reaction attempt.'),
      ],
    );
  }
}
