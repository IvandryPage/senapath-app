import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'theme_settings_repository.dart';

class ThemeSettingsState {
  const ThemeSettingsState({
    this.themeMode = ThemeMode.system,
    this.isLoaded = false,
    this.isSaving = false,
    this.error,
  });

  final ThemeMode themeMode;
  final bool isLoaded;
  final bool isSaving;
  final String? error;
}

class ThemeSettingsCubit extends Cubit<ThemeSettingsState> {
  ThemeSettingsCubit(this._repository) : super(const ThemeSettingsState());

  final ThemeSettingsRepository _repository;

  Future<void> load() async {
    if (state.isLoaded && state.error == null) return;
    try {
      final mode = await _repository.load();
      if (isClosed) return;
      emit(ThemeSettingsState(themeMode: mode, isLoaded: true));
    } catch (_) {
      if (isClosed) return;
      emit(
        const ThemeSettingsState(
          isLoaded: true,
          error: 'Preferensi tema tidak dapat dimuat.',
        ),
      );
    }
  }

  Future<void> select(ThemeMode mode) async {
    if (state.isSaving || mode == state.themeMode && state.isLoaded) return;
    final previousMode = state.themeMode;
    emit(
      ThemeSettingsState(
        themeMode: mode,
        isLoaded: state.isLoaded,
        isSaving: true,
      ),
    );
    try {
      await _repository.save(mode);
      if (isClosed) return;
      emit(ThemeSettingsState(themeMode: mode, isLoaded: true));
    } catch (_) {
      if (isClosed) return;
      emit(
        ThemeSettingsState(
          themeMode: previousMode,
          isLoaded: true,
          error: 'Pilihan tema tidak dapat disimpan. Coba lagi.',
        ),
      );
    }
  }

}
