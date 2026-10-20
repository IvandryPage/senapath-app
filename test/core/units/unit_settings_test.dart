import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/units/unit_settings_cubit.dart';
import 'package:senapath/core/units/unit_settings_repository.dart';
import 'package:senapath/core/units/unit_system.dart';

import '../../helpers/test_database.dart';

void main() {
  group('UnitSystem', () {
    test('parses storage values defensively', () {
      expect(UnitSystem.fromStorage('metric'), UnitSystem.metric);
      expect(UnitSystem.fromStorage('imperial'), UnitSystem.imperial);
      expect(UnitSystem.fromStorage(null), UnitSystem.metric);
      expect(UnitSystem.fromStorage('IMPERIAL'), UnitSystem.metric);
      expect(UnitSystem.fromStorage('garbage'), UnitSystem.metric);
    });

    test('exposes storage values', () {
      expect(UnitSystem.metric.storageValue, 'metric');
      expect(UnitSystem.imperial.storageValue, 'imperial');
    });
  });

  group('UnitSettingsRepository', () {
    test('defaults to metric and persists the selection', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = UnitSettingsRepository(database);

      expect(await repository.load(), UnitSystem.metric);

      await repository.save(UnitSystem.imperial);
      expect(await repository.load(), UnitSystem.imperial);

      await repository.save(UnitSystem.metric);
      expect(await repository.load(), UnitSystem.metric);
    });
  });

  group('UnitSettingsCubit', () {
    test('loads the stored unit system once', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = UnitSettingsRepository(database);
      await repository.save(UnitSystem.imperial);

      final cubit = UnitSettingsCubit(repository);
      addTearDown(cubit.close);

      expect(cubit.state.isLoaded, isFalse);
      await cubit.load();
      expect(cubit.state.unitSystem, UnitSystem.imperial);
      expect(cubit.state.isLoaded, isTrue);

      await repository.save(UnitSystem.metric);
      await cubit.load();
      expect(cubit.state.unitSystem, UnitSystem.imperial, reason: 'load() should not reload');
    });

    test('select() persists and emits the new unit system', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = UnitSettingsRepository(database);
      final cubit = UnitSettingsCubit(repository);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.select(UnitSystem.imperial);

      expect(cubit.state.unitSystem, UnitSystem.imperial);
      expect(cubit.state.isSaving, isFalse);
      expect(await repository.load(), UnitSystem.imperial);
    });
  });
}
