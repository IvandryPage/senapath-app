import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/storage/app_database.dart';
import '../../authentication/data/custom_auth_session_manager.dart';
import '../domain/rider_progress.dart';

class RiderProfileRepository {
  const RiderProfileRepository(
    this._database, {
    this._cloudClient,
    this._sessionManager,
  });

  static const _styleKey = 'rider_style_v1';
  final AppDatabase _database;
  final SupabaseClient? _cloudClient;
  final CustomAuthSessionManager? _sessionManager;

  Future<RiderStyle> loadStyle() async {
    final cloudStyle = await loadCloudStyle();
    if (cloudStyle != null) {
      await _saveLocalStyle(cloudStyle);
      return cloudStyle;
    }
    return loadLocalStyle();
  }

  Future<RiderStyle> loadLocalStyle() async {
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

  Future<void> saveStyle(RiderStyle style) => _saveLocalStyle(style);

  Future<void> saveCloudProfile({
    required RiderStyle style,
    int? level,
    int? experience,
  }) async {
    final manager = _sessionManager;
    final client = _cloudClient;
    if (manager?.currentUserId == null || client == null) return;
    await manager!.requireAccessToken();
    await client.rpc(
      'set_my_rider_profile',
      params: {
        'p_rider_style': style.name,
        'p_rider_level': level ?? 1,
        'p_experience': experience ?? 0,
      },
    );
  }

  Future<RiderStyle?> loadCloudStyle() async {
    final manager = _sessionManager;
    final client = _cloudClient;
    if (manager?.currentUserId == null || client == null) return null;
    await manager!.requireAccessToken();
    final row = await client
        .from('rider_profiles')
        .select('rider_style')
        .eq('user_id', manager.currentUserId!)
        .maybeSingle();
    return row == null ? null : RiderStyle.fromName(row['rider_style']);
  }

  Future<void> _saveLocalStyle(RiderStyle style) async {
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
