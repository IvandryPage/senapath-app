import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/storage/app_database.dart';
import '../../account_sync/data/account_cloud_gateway.dart';
import '../../authentication/data/custom_auth_session_manager.dart';
import '../domain/rider_progress.dart';

class RiderProfileRepository {
  /// Membuat repositori profil rider dengan penyimpanan lokal dan cloud opsional.
  const RiderProfileRepository(
    this._database, {
    this._cloudClient,
    this._sessionManager,
    this._cloudGateway,
  });

  static const _styleKey = 'rider_style_v1';
  static const _appearanceKey = 'rider_appearance_v1';
  static const _bonusExperienceKey = 'rider_bonus_experience_v1';
  final AppDatabase _database;
  final SupabaseClient? _cloudClient;
  final CustomAuthSessionManager? _sessionManager;
  final AccountCloudGateway? _cloudGateway;

  /// Memuat gaya rider dari cloud bila tersedia, lalu menyimpannya secara lokal.
  Future<RiderStyle> loadStyle() async {
    final cloudStyle = await loadCloudStyle();
    if (cloudStyle != null) {
      await _saveLocalStyle(cloudStyle);
      return cloudStyle;
    }
    return loadLocalStyle();
  }

  /// Membaca gaya rider dari preferensi lokal tanpa mengakses cloud.
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

  /// Menyimpan gaya rider ke penyimpanan lokal.
  Future<void> saveStyle(RiderStyle style) => _saveLocalStyle(style);

  /// Memuat tampilan rider dari akun online atau lokal, lalu menyinkronkannya.
  Future<RiderAppearance> loadAppearance() async {
    final gateway = _cloudGateway;
    if (gateway != null && gateway.isSignedIn) {
      try {
        final remote = await gateway.pullSetting(_appearanceKey);
        if (remote != null) {
          final appearance = RiderAppearance.fromJson(
            Map<String, dynamic>.from(remote as Map),
          );
          await _saveLocalAppearance(appearance);
          return appearance;
        }
        final local = await _loadLocalAppearance();
        await gateway.pushSetting(_appearanceKey, local.toJson());
        return local;
      } catch (_) {
        // Fall back to local appearance when the cloud is unavailable.
      }
    }
    return _loadLocalAppearance();
  }

  /// Menyimpan tampilan rider secara lokal dan mencoba mengunggahnya ke cloud.
  Future<void> saveAppearance(RiderAppearance appearance) async {
    await _saveLocalAppearance(appearance);
    final gateway = _cloudGateway;
    if (gateway != null && gateway.isSignedIn) {
      try {
        await gateway.pushSetting(_appearanceKey, appearance.toJson());
      } catch (_) {
        // Persist locally only; a later load retries the cloud copy.
      }
    }
  }

  /// Memuat bonus experience dari akun online atau penyimpanan lokal.
  Future<int> loadBonusExperience() async {
    final gateway = _cloudGateway;
    if (gateway != null && gateway.isSignedIn) {
      try {
        final remote = await gateway.pullSetting(_bonusExperienceKey);
        final bonus = _parseBonusExperience(remote);
        if (bonus != null) {
          await _saveLocalBonusExperience(bonus);
          return bonus;
        }
        final local = await _loadLocalBonusExperience();
        await gateway.pushSetting(_bonusExperienceKey, local);
        return local;
      } catch (_) {
        // Fall back to the locally stored value when the cloud is unavailable.
      }
    }
    return _loadLocalBonusExperience();
  }

  /// Menyimpan bonus experience secara lokal dan mencoba menyinkronkannya.
  Future<void> saveBonusExperience(int bonusExperience) async {
    await _saveLocalBonusExperience(bonusExperience);
    final gateway = _cloudGateway;
    if (gateway != null && gateway.isSignedIn) {
      try {
        await gateway.pushSetting(_bonusExperienceKey, bonusExperience);
      } catch (_) {
        // Persist locally only; a later load retries the cloud copy.
      }
    }
  }

  /// Menyimpan gaya, level, dan experience rider ke profil cloud pengguna.
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

  /// Persists the full gamification progress and rider appearance so
  /// achievements, XP, and level restore exactly on every signed-in device.
  Future<void> saveCloudProgress(
    RiderProgress progress,
    RiderAppearance appearance,
  ) async {
    final gateway = _cloudGateway;
    if (gateway == null || !gateway.isSignedIn) {
      await saveCloudProfile(
        style: progress.style,
        level: progress.level,
        experience: progress.experience,
      );
      return;
    }
    await gateway.pushRiderProgress(
      style: progress.style,
      level: progress.level,
      experience: progress.experience,
      distanceMeters: progress.distanceMeters,
      completedRides: progress.completedRides,
      rideDurationSeconds: progress.rideDurationSeconds,
      weekendRides: progress.weekendRides,
      appearance: appearance,
    );
  }

  /// Mengambil progres rider lengkap dari cloud bila pengguna sudah masuk.
  Future<CloudRiderProgress?> loadCloudProgress() async {
    final gateway = _cloudGateway;
    if (gateway == null || !gateway.isSignedIn) return null;
    return gateway.pullRiderProgress();
  }

  /// Mengambil gaya rider tersimpan dari profil cloud pengguna.
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

  /// Membaca tampilan rider dari preferensi lokal dan memvalidasi formatnya.
  Future<RiderAppearance> _loadLocalAppearance() async {
    final row = await (_database.select(
      _database.appPreferences,
    )..where((item) => item.key.equals(_appearanceKey))).getSingleOrNull();
    if (row == null) return const RiderAppearance();
    final decoded = jsonDecode(row.value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Tampilan karakter rider tersimpan tidak valid.',
      );
    }
    return RiderAppearance.fromJson(decoded);
  }

  /// Menulis tampilan rider ke preferensi lokal dengan menimpa nilai lama.
  Future<void> _saveLocalAppearance(RiderAppearance appearance) async {
    await _database
        .into(_database.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            key: _appearanceKey,
            value: jsonEncode(appearance.toJson()),
          ),
        );
  }

  /// Mengubah nilai bonus experience dari berbagai tipe menjadi int non-negatif.
  int? _parseBonusExperience(Object? value) {
    if (value is int && value >= 0) return value;
    if (value is num && value >= 0) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed >= 0) return parsed;
    }
    return null;
  }

  /// Membaca bonus experience lokal, mengembalikan 0 bila tidak ada.
  Future<int> _loadLocalBonusExperience() async {
    final row = await (_database.select(
      _database.appPreferences,
    )..where((item) => item.key.equals(_bonusExperienceKey))).getSingleOrNull();
    if (row == null) return 0;
    return _parseBonusExperience(jsonDecode(row.value)) ?? 0;
  }

  /// Menyimpan bonus experience ke preferensi lokal.
  Future<void> _saveLocalBonusExperience(int bonusExperience) async {
    await _database
        .into(_database.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            key: _bonusExperienceKey,
            value: jsonEncode(bonusExperience),
          ),
        );
  }

  /// Menyimpan nama gaya rider ke preferensi lokal.
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
