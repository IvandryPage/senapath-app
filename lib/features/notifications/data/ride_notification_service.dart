import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

abstract interface class RideNotificationService {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  });
  Future<void> scheduleWeeklyReminder({
    required Set<int> weekdays,
    required int hour,
    required int minute,
  });
  Future<void> cancelWeeklyReminders();
}

class LocalRideNotificationService implements RideNotificationService {
  LocalRideNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'ride_progress';
  static const _reminderIds = [7101, 7102, 7103, 7104, 7105, 7106, 7107];

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    timezone_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(timezone.getLocation(localTimezone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final androidGranted = await android?.requestNotificationsPermission();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return androidGranted ?? iosGranted ?? true;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Progres gowes',
          channelDescription: 'Progres rute dan checkpoint sesi bersepeda.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  @override
  Future<void> scheduleWeeklyReminder({
    required Set<int> weekdays,
    required int hour,
    required int minute,
  }) async {
    await initialize();
    await cancelWeeklyReminders();
    final now = timezone.TZDateTime.now(timezone.local);
    for (final weekday in weekdays) {
      if (weekday < DateTime.monday || weekday > DateTime.sunday) continue;
      var scheduled = timezone.TZDateTime(
        timezone.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        id: _reminderIds[weekday - DateTime.monday],
        title: 'Waktunya gowes?',
        body: 'Sedikit latihan hari ini bisa bantu capai target mingguanmu.',
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'training_reminders',
            'Pengingat latihan',
            channelDescription: 'Pengingat latihan sepeda mingguan.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  @override
  Future<void> cancelWeeklyReminders() async {
    await initialize();
    for (final id in _reminderIds) {
      await _plugin.cancel(id: id);
    }
  }
}
