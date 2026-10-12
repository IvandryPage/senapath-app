import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/features/notifications/data/notification_settings_repository.dart';
import 'package:senapath/features/notifications/data/ride_notification_service.dart';
import 'package:senapath/features/notifications/presentation/notification_settings_cubit.dart';

void main() {
  late AppDatabase database;
  late NotificationSettingsRepository repository;
  late _FakeRideNotificationService notifications;
  late NotificationSettingsCubit cubit;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = NotificationSettingsRepository(database);
    notifications = _FakeRideNotificationService();
    cubit = NotificationSettingsCubit(repository, notifications);
  });

  tearDown(() async {
    await cubit.close();
    await database.close();
  });

  test('denied notification permission leaves settings unchanged', () async {
    notifications.permissionGranted = false;
    await cubit.load();

    await cubit.update(cubit.state.settings.copyWith(remindersEnabled: true));

    expect(cubit.state.settings.remindersEnabled, isFalse);
    expect(cubit.state.error, contains('Izin notifikasi'));
    expect((await repository.load()).remindersEnabled, isFalse);
    expect(notifications.scheduledWeekdays, isEmpty);
  });

  test(
    'saves and schedules enabled reminders after permission is granted',
    () async {
      await cubit.load();

      final requested = cubit.state.settings.copyWith(
        remindersEnabled: true,
        reminderWeekdays: {1, 5},
        reminderHour: 7,
        reminderMinute: 30,
      );
      await cubit.update(requested);

      expect(cubit.state.settings.remindersEnabled, isTrue);
      expect(cubit.state.error, isNull);
      final persisted = await repository.load();
      expect(persisted.remindersEnabled, isTrue);
      expect(persisted.reminderWeekdays, {1, 5});
      expect(persisted.reminderHour, 7);
      expect(persisted.reminderMinute, 30);
      expect(notifications.permissionRequests, 1);
      expect(notifications.scheduledWeekdays, {1, 5});
      expect(notifications.scheduledHour, 7);
      expect(notifications.scheduledMinute, 30);
    },
  );

  test('restores persisted settings when reminder scheduling fails', () async {
    await cubit.load();
    notifications.failScheduling = true;
    final requested = cubit.state.settings.copyWith(remindersEnabled: true);

    await cubit.update(requested);

    expect(cubit.state.settings.remindersEnabled, isFalse);
    expect(cubit.state.error, contains('gagal disimpan'));
    expect((await repository.load()).remindersEnabled, isFalse);
  });
}

class _FakeRideNotificationService implements RideNotificationService {
  bool permissionGranted = true;
  bool failScheduling = false;
  int permissionRequests = 0;
  Set<int> scheduledWeekdays = {};
  int? scheduledHour;
  int? scheduledMinute;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Future<void> scheduleWeeklyReminder({
    required Set<int> weekdays,
    required int hour,
    required int minute,
  }) async {
    if (failScheduling) throw StateError('schedule failed');
    scheduledWeekdays = weekdays;
    scheduledHour = hour;
    scheduledMinute = minute;
  }

  @override
  Future<void> cancelWeeklyReminders() async {
    scheduledWeekdays = {};
    scheduledHour = null;
    scheduledMinute = null;
  }
}
