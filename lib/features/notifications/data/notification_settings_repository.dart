import 'dart:convert';

import '../../../core/storage/app_database.dart';

class RideNotificationSettings {
  /// Membuat pengaturan notifikasi perjalanan dengan nilai bawaan.
  const RideNotificationSettings({
    this.routeProgressEnabled = true,
    this.remindersEnabled = false,
    this.reminderWeekdays = const {2, 4, 6},
    this.reminderHour = 18,
    this.reminderMinute = 0,
  });

  final bool routeProgressEnabled;
  final bool remindersEnabled;
  final Set<int> reminderWeekdays;
  final int reminderHour;
  final int reminderMinute;

  /// Menyalin pengaturan dengan perubahan opsional pada tiap kolom.
  RideNotificationSettings copyWith({
    bool? routeProgressEnabled,
    bool? remindersEnabled,
    Set<int>? reminderWeekdays,
    int? reminderHour,
    int? reminderMinute,
  }) => RideNotificationSettings(
    routeProgressEnabled: routeProgressEnabled ?? this.routeProgressEnabled,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    reminderWeekdays: reminderWeekdays ?? this.reminderWeekdays,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
  );

  /// Mengubah pengaturan menjadi peta JSON dengan hari pengingat terurut.
  Map<String, Object?> toJson() => {
    'routeProgressEnabled': routeProgressEnabled,
    'remindersEnabled': remindersEnabled,
    'reminderWeekdays': reminderWeekdays.toList()..sort(),
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
  };

  /// Membangun pengaturan dari JSON sekaligus memvalidasi hari dan waktu.
  factory RideNotificationSettings.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Pengaturan notifikasi tidak valid.');
    }
    final weekdays = value['reminderWeekdays'];
    final hour = value['reminderHour'];
    final minute = value['reminderMinute'];
    if (weekdays is! List ||
        weekdays.any((day) => day is! int || day < 1 || day > 7) ||
        hour is! int ||
        hour < 0 ||
        hour > 23 ||
        minute is! int ||
        minute < 0 ||
        minute > 59) {
      throw const FormatException('Jadwal notifikasi tidak valid.');
    }
    return RideNotificationSettings(
      routeProgressEnabled: value['routeProgressEnabled'] == true,
      remindersEnabled: value['remindersEnabled'] == true,
      reminderWeekdays: weekdays.cast<int>().toSet(),
      reminderHour: hour,
      reminderMinute: minute,
    );
  }
}

class NotificationSettingsRepository {
  /// Membuat repositori pengaturan notifikasi dengan basis data lokal.
  const NotificationSettingsRepository(this._database);

  static const _key = 'ride_notification_settings_v1';
  final AppDatabase _database;

  /// Memuat pengaturan notifikasi tersimpan atau nilai bawaan bila kosong.
  Future<RideNotificationSettings> load() async {
    final row = await (_database.select(
      _database.appPreferences,
    )..where((preference) => preference.key.equals(_key))).getSingleOrNull();
    if (row == null) return const RideNotificationSettings();
    return RideNotificationSettings.fromJson(jsonDecode(row.value));
  }

  /// Menyimpan pengaturan notifikasi terenkode ke preferensi lokal.
  Future<void> save(RideNotificationSettings settings) async {
    await _database
        .into(_database.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            key: _key,
            value: jsonEncode(settings.toJson()),
          ),
        );
  }
}
