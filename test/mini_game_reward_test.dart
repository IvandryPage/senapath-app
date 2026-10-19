import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/features/gamification/data/rider_profile_repository.dart';
import 'package:senapath/features/gamification/domain/rider_progress.dart';
import 'package:senapath/features/gamification/presentation/rider_gamification_cubit.dart';

void main() {
  test('fromSessions folds bonus experience into the total', () {
    final progress = RiderProgress.fromSessions(
      const [],
      style: RiderStyle.explorer,
      bonusExperience: 10,
    );

    expect(progress.experience, 10);
    expect(progress.bonusExperience, 10);
    expect(progress.level, 1);
  });

  test('mini-game rewards accumulate and survive a reload', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final cubit = RiderGamificationCubit(RiderProfileRepository(database));
    addTearDown(cubit.close);

    await cubit.load(const []);
    expect(cubit.state.progress, isNotNull);
    expect(cubit.state.progress!.experience, 0);

    await cubit.awardExperience(10);
    expect(cubit.state.progress!.experience, 10);
    expect(cubit.state.progress!.bonusExperience, 10);

    await cubit.awardExperience(10);
    expect(cubit.state.progress!.experience, 20);

    final restored = RiderGamificationCubit(RiderProfileRepository(database));
    addTearDown(restored.close);
    await restored.load(const []);
    expect(restored.state.progress!.experience, 20);
    expect(restored.state.progress!.bonusExperience, 20);
  });
}
