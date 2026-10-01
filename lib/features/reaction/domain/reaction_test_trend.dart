import 'reaction_test_result.dart';

class ReactionTestTrend {
  const ReactionTestTrend({
    required this.recentAverageMilliseconds,
    required this.previousAverageMilliseconds,
  });

  final int recentAverageMilliseconds;
  final int previousAverageMilliseconds;

  int get differenceMilliseconds =>
      recentAverageMilliseconds - previousAverageMilliseconds;

  static ReactionTestTrend? fromResults(List<ReactionTestResult> results) {
    final scoredResults =
        results
            .where((result) => result.averageReactionMilliseconds != null)
            .toList()
          ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    if (scoredResults.length < 6) return null;

    final recent = scoredResults
        .take(3)
        .map((result) => result.averageReactionMilliseconds!);
    final previous = scoredResults
        .skip(3)
        .take(3)
        .map((result) => result.averageReactionMilliseconds!);

    return ReactionTestTrend(
      recentAverageMilliseconds: _average(recent),
      previousAverageMilliseconds: _average(previous),
    );
  }

  static int _average(Iterable<int> values) =>
      (values.reduce((total, value) => total + value) / 3).round();
}
