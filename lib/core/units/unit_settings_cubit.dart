import 'package:flutter_bloc/flutter_bloc.dart';

import 'unit_settings_repository.dart';
import 'unit_system.dart';

class UnitSettingsState {
  const UnitSettingsState({
    this.unitSystem = UnitSystem.metric,
    this.isLoaded = false,
    this.isSaving = false,
  });

  final UnitSystem unitSystem;
  final bool isLoaded;
  final bool isSaving;
}

class UnitSettingsCubit extends Cubit<UnitSettingsState> {
  UnitSettingsCubit(this._repository) : super(const UnitSettingsState());

  final UnitSettingsRepository _repository;

  Future<void> load() async {
    if (state.isLoaded) return;
    final unitSystem = await _repository.load();
    emit(UnitSettingsState(unitSystem: unitSystem, isLoaded: true));
  }

  Future<void> select(UnitSystem unitSystem) async {
    emit(
      UnitSettingsState(
        unitSystem: state.unitSystem,
        isLoaded: state.isLoaded,
        isSaving: true,
      ),
    );
    try {
      await _repository.save(unitSystem);
      emit(UnitSettingsState(unitSystem: unitSystem, isLoaded: true));
    } catch (_) {
      emit(UnitSettingsState(unitSystem: state.unitSystem, isLoaded: true));
      rethrow;
    }
  }
}
