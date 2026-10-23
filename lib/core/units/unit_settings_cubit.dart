import 'package:flutter_bloc/flutter_bloc.dart';

import 'unit_settings_repository.dart';
import 'unit_system.dart';

class UnitSettingsState {
  /// Membuat state pengaturan satuan beserta status muat dan simpan.
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
  /// Membuat cubit yang menyimpan preferensi satuan melalui repositori.
  UnitSettingsCubit(this._repository) : super(const UnitSettingsState());

  final UnitSettingsRepository _repository;

  /// Memuat satuan tersimpan sekali saja lalu menandai state sudah siap.
  Future<void> load() async {
    if (state.isLoaded) return;
    final unitSystem = await _repository.load();
    emit(UnitSettingsState(unitSystem: unitSystem, isLoaded: true));
  }

  /// Menyimpan pilihan satuan baru dan memulihkan state lama bila gagal.
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
