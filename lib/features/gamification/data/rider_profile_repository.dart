import 'dart:convert';

import '../../../core/storage/app_database.dart';
import '../domain/rider_progress.dart';

class RiderProfileRepository {
  const RiderProfileRepository(this._database);

  static const _styleKey = 'rider_style_v1';
  final AppDatabase _database;

  Future<RiderStyle> loadStyle() async {
    final row = await (_database.select(
      _database.appPreferences,
    )..where((item) => item.key.equals(_styleKey))).getSingleOrNull();
    if (row == null) return RiderStyle.explorer;
    final decoded = jsonDecode(row.value);
    if (decoded is! String) {
      throw const FormatException('Gaya rider tersimpan tidak valid.');
    }
    return RiderStyle.values.firstWhere(
      (style) => style.name == decoded,
      orElse: () => RiderStyle.explorer,
    );
  }

  Future<void> saveStyle(RiderStyle style) async {
    await _database
        .into(_database.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            key: _styleKey,
            value: jsonEncode(style.name),
          ),
        );
  }
}
