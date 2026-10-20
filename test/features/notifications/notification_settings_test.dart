import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/notifications/data/notification_settings_repository.dart';

import '../../helpers/test_database.dart';

void main() {
  group('RideNotificationSettings', () {
    test('has sensible defaults', () {
      const settings = RideNotificationSettings();
      expect(settings.routeProgressEnabled, isTrue);
      expect(settings.remindersEnabled, isFalse);
      expect(settings.reminderWeekdays, {2, 4, 6});
      expect(settings.reminderHour, 18);
      expect(settings.reminderMinute, 0);
    });

    test('copyWith keeps previous values', () {
      const settings = RideNotificationSettings();
      final updated = settings.copyWith(
        remindersEnabled: true,
        reminderWeekdays: {1},
      );
      expect(updated.remindersEnabled, isTrue);
      expect(updated.reminderWeekdays, {1});
      expect(updated.routeProgressEnabled, isTrue);
      expect(updated.reminderHour, 18);
    });

    test('round-trips through JSON with sorted weekdays', () {
      const settings = RideNotificationSettings(
        routeProgressEnabled: false,
        remindersEnabled: true,
        reminderWeekdays: {7, 1, 4},
        reminderHour: 6,
        reminderMinute: 30,
      );
      final json = settings.toJson();
      expect(json['reminderWeekdays'], [1, 4, 7]);

      final restored = RideNotificationSettings.fromJson(json);
      expect(restored.routeProgressEnabled, isFalse);
      expect(restored.remindersEnabled, isTrue);
      expect(restored.reminderWeekdays, {7, 1, 4});
      expect(restored.reminderHour, 6);
      expect(restored.reminderMinute, 30);
    });

    test('tolerates missing flags by disabling them', () {
      final restored = RideNotificationSettings.fromJson({
        'reminderWeekdays': [2],
        'reminderHour': 8,
        'reminderMinute': 0,
      });
      expect(restored.routeProgressEnabled, isFalse);
      expect(restored.remindersEnabled, isFalse);
    });

    test('rejects invalid payloads', () {
      expect(
        () => RideNotificationSettings.fromJson('nope'),
        throwsFormatException,
      );
      expect(
        () => RideNotificationSettings.fromJson({
          'reminderWeekdays': [0],
          'reminderHour': 8,
          'reminderMinute': 0,
        }),
        throwsFormatException,
      );
      expect(
        () => RideNotificationSettings.fromJson({
          'reminderWeekdays': [8],
          'reminderHour': 8,
          'reminderMinute': 0,
        }),
        throwsFormatException,
      );
      expect(
        () => RideNotificationSettings.fromJson({
          'reminderWeekdays': [1],
          'reminderHour': 24,
          'reminderMinute': 0,
        }),
        throwsFormatException,
      );
      expect(
        () => RideNotificationSettings.fromJson({
          'reminderWeekdays': [1],
          'reminderHour': 8,
          'reminderMinute': 60,
        }),
        throwsFormatException,
      );
      expect(
        () => RideNotificationSettings.fromJson({
          'reminderWeekdays': 'x',
          'reminderHour': 8,
          'reminderMinute': 0,
        }),
        throwsFormatException,
      );
    });
  });

  group('NotificationSettingsRepository', () {
    test('returns defaults when nothing is stored', () async {
      final repository = NotificationSettingsRepository(createTestDatabase());
      final settings = await repository.load();
      expect(settings.routeProgressEnabled, isTrue);
      expect(settings.remindersEnabled, isFalse);
    });

    test('persists settings', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = NotificationSettingsRepository(database);

      await repository.save(
        const RideNotificationSettings(
          routeProgressEnabled: false,
          remindersEnabled: true,
          reminderWeekdays: {3},
          reminderHour: 7,
          reminderMinute: 15,
        ),
      );

      final fresh = NotificationSettingsRepository(database);
      final settings = await fresh.load();
      expect(settings.routeProgressEnabled, isFalse);
      expect(settings.remindersEnabled, isTrue);
      expect(settings.reminderWeekdays, {3});
      expect(settings.reminderHour, 7);
      expect(settings.reminderMinute, 15);
    });
  });
}
