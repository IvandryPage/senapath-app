import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/reaction/data/reaction_test_repository.dart';
import 'package:senapath/features/reaction/presentation/reaction_test_cubit.dart';
import 'package:senapath/features/reaction/presentation/reaction_test_screen.dart';
import 'package:senapath/features/reaction/domain/reaction_test_result.dart';
import 'package:senapath/features/reaction/domain/reaction_test_trend.dart';

void main() {
  testWidgets('shows a non-AI rest reminder when test history exists', (
    tester,
  ) async {
    final cubit = ReactionTestCubit(
      _FakeReactionTestRepository([_result(1, 240)]),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: Scaffold(body: ReactionTestScreen())),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Pengingat istirahat'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Pengingat istirahat'), findsOneWidget);
    expect(find.textContaining('bukan keluaran AI'), findsOneWidget);
  });

  test('trend waits for six completed tests with scored responses', () {
    final results = [
      for (var index = 0; index < 5; index++) _result(index, 240),
      _result(6, null),
    ];

    expect(ReactionTestTrend.fromResults(results), isNull);
  });

  test('compares latest and previous groups of three scored tests', () {
    final results = [
      _result(1, 310),
      _result(7, null),
      _result(2, 300),
      _result(3, 320),
      _result(4, 230),
      _result(5, 220),
      _result(6, 210),
    ];

    final trend = ReactionTestTrend.fromResults(results)!;

    expect(trend.recentAverageMilliseconds, 220);
    expect(trend.previousAverageMilliseconds, 310);
    expect(trend.differenceMilliseconds, -90);
  });
}

ReactionTestResult _result(int day, int? reactionMilliseconds) =>
    ReactionTestResult(
      id: 'result-$day',
      completedAt: DateTime.utc(2026, 10, day),
      durationMilliseconds: 120000,
      attempts: [
        if (reactionMilliseconds != null)
          ReactionAttempt(
            wasCorrect: true,
            reactionMilliseconds: reactionMilliseconds,
          ),
      ],
    );

class _FakeReactionTestRepository implements ReactionTestRepository {
  const _FakeReactionTestRepository(this.results);

  final List<ReactionTestResult> results;

  @override
  Future<List<ReactionTestResult>> loadRecent({int limit = 30}) async =>
      results;

  @override
  Future<void> save(ReactionTestResult result) async {}
}
