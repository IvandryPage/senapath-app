import '../../session/domain/ride_session.dart';

enum ProgressPeriod { week, month }

enum GoalMetric { completedSessions, distanceMeters, activeSeconds }

class ActivityGoal {
  /// Membuat target aktivitas dengan id, metrik, target, dan periode.
  const ActivityGoal({
    required this.id,
    required this.metric,
    required this.target,
    required this.period,
  });

  final String id;
  final GoalMetric metric;
  final double target;
  final ProgressPeriod period;

  /// Mengubah target aktivitas menjadi peta JSON.
  Map<String, Object?> toJson() => {
    'id': id,
    'metric': metric.name,
    'target': target,
    'period': period.name,
  };

  /// Membangun target dari JSON sekaligus memvalidasi metrik dan nilainya.
  factory ActivityGoal.fromJson(Map<String, dynamic> json) {
    final metric = GoalMetric.values.firstWhere(
      (value) => value.name == json['metric'],
    );
    final period = ProgressPeriod.values.firstWhere(
      (value) => value.name == json['period'],
    );
    final target = (json['target'] as num).toDouble();
    if (!target.isFinite || target <= 0) {
      throw const FormatException('Target aktivitas tidak valid.');
    }
    return ActivityGoal(
      id: json['id'] as String,
      metric: metric,
      target: target,
      period: period,
    );
  }
}

class ActivityProgress {
  /// Membuat ringkasan progres untuk suatu periode beserta sesi penyusunnya.
  const ActivityProgress({
    required this.period,
    required this.startsAt,
    required this.endsAt,
    required this.sessionIds,
    required this.distanceMeters,
    required this.activeSeconds,
  });

  final ProgressPeriod period;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<String> sessionIds;
  final double distanceMeters;
  final int activeSeconds;

  /// Jumlah sesi selesai yang termasuk dalam periode ini.
  int get completedSessions => sessionIds.length;

  /// Mengambil nilai progres sesuai metrik target yang dipilih.
  double valueFor(GoalMetric metric) => switch (metric) {
    GoalMetric.completedSessions => completedSessions.toDouble(),
    GoalMetric.distanceMeters => distanceMeters,
    GoalMetric.activeSeconds => activeSeconds.toDouble(),
  };

  /// Menghitung rasio progres terhadap target, dibatasi antara 0 dan 1.
  double progressFor(ActivityGoal goal) =>
      (valueFor(goal.metric) / goal.target).clamp(0, 1).toDouble();
}

class ActivityProgressCalculator {
  /// Membuat kalkulator progres aktivitas tanpa keadaan.
  const ActivityProgressCalculator();

  /// Menghitung progres sesi selesai untuk pekan/bulan berjalan atau sebelumnya.
  ActivityProgress calculate(
    Iterable<RideSessionSnapshot> sessions, {
    required DateTime now,
    required ProgressPeriod period,
    bool previousPeriod = false,
  }) {
    final localNow = now.toLocal();
    final currentStart = switch (period) {
      ProgressPeriod.week => DateTime(
        localNow.year,
        localNow.month,
        localNow.day,
      ).subtract(Duration(days: localNow.weekday - DateTime.monday)),
      ProgressPeriod.month => DateTime(localNow.year, localNow.month),
    };
    final startsAt = previousPeriod
        ? switch (period) {
            ProgressPeriod.week => currentStart.subtract(
              const Duration(days: 7),
            ),
            ProgressPeriod.month => DateTime(
              currentStart.year,
              currentStart.month - 1,
            ),
          }
        : currentStart;
    final endsAt = switch (period) {
      ProgressPeriod.week => startsAt.add(const Duration(days: 7)),
      ProgressPeriod.month => DateTime(startsAt.year, startsAt.month + 1),
    };
    final includedById = <String, RideSessionSnapshot>{};
    for (final session in sessions) {
      if (session.status == RideSessionStatus.completed &&
          !session.startedAt.toLocal().isBefore(startsAt) &&
          session.startedAt.toLocal().isBefore(endsAt)) {
        includedById.putIfAbsent(session.id, () => session);
      }
    }
    final included = includedById.values.toList(growable: false);
    return ActivityProgress(
      period: period,
      startsAt: startsAt,
      endsAt: endsAt,
      sessionIds: included.map((session) => session.id).toList(growable: false),
      distanceMeters: included.fold<double>(
        0,
        (total, session) => total + session.distanceMeters,
      ),
      activeSeconds: included.fold<int>(
        0,
        (total, session) =>
            total +
            session.durationAt(session.endedAt ?? session.startedAt).inSeconds,
      ),
    );
  }
}
