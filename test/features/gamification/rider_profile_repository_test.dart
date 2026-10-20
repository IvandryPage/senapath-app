import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/features/gamification/data/rider_profile_repository.dart';
import 'package:senapath/features/gamification/domain/rider_progress.dart';

import '../../helpers/test_database.dart';

void main() {
  group('RiderProfileRepository', () {
    test('defaults to the explorer style', () async {
      final repository = RiderProfileRepository(createTestDatabase());
      expect(await repository.loadLocalStyle(), RiderStyle.explorer);
    });

    test('persists and restores the rider style', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = RiderProfileRepository(database);

      await repository.saveStyle(RiderStyle.climber);
      expect(await repository.loadLocalStyle(), RiderStyle.climber);

      final freshRepository = RiderProfileRepository(database);
      expect(await freshRepository.loadLocalStyle(), RiderStyle.climber);
    });

    test('persists and restores the rider appearance', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = RiderProfileRepository(database);

      const appearance = RiderAppearance(
        kitColor: RiderKitColor.violet,
        accessory: RiderAccessory.glasses,
      );
      await repository.saveAppearance(appearance);
      expect(await repository.loadAppearance(), appearance);

      final freshRepository = RiderProfileRepository(database);
      expect(await freshRepository.loadAppearance(), appearance);
    });

    test('persists and restores bonus experience', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = RiderProfileRepository(database);

      expect(await repository.loadBonusExperience(), 0);
      await repository.saveBonusExperience(120);
      expect(await repository.loadBonusExperience(), 120);
    });

    test('falls back to explorer for unknown stored styles', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      await database
          .into(database.appPreferences)
          .insert(
            AppPreferencesCompanion.insert(
              key: 'rider_style_v1',
              value: '"not-a-style"',
            ),
          );

      final repository = RiderProfileRepository(database);
      expect(await repository.loadLocalStyle(), RiderStyle.explorer);
    });
  });
}
