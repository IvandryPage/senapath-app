import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/app/theme/theme_settings_cubit.dart';
import 'package:senapath/app/theme/theme_settings_repository.dart';
import 'package:senapath/core/storage/app_database.dart';

void main() {
  late AppDatabase database;
  late ThemeSettingsCubit cubit;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    cubit = ThemeSettingsCubit(ThemeSettingsRepository(database));
  });

  tearDown(() async {
    await cubit.close();
    await database.close();
  });

  test('loads system theme by default and persists a selected theme', () async {
    await cubit.load();
    expect(cubit.state.themeMode, ThemeMode.system);

    await cubit.select(ThemeMode.light);
    expect(cubit.state.themeMode, ThemeMode.light);

    await cubit.select(ThemeMode.dark);

    expect(cubit.state.themeMode, ThemeMode.dark);
    expect(cubit.state.isSaving, isFalse);

    final restored = ThemeSettingsCubit(ThemeSettingsRepository(database));
    addTearDown(restored.close);
    await restored.load();
    expect(restored.state.themeMode, ThemeMode.dark);
  });
}
