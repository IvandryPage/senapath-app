import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

abstract interface class RideNotificationService {
  /// Menyiapkan layanan notifikasi dan zona waktu perangkat.
  Future<void> initialize();
  /// Meminta izin notifikasi dan mengembalikan status pemberiannya.
  Future<bool> requestPermission();
  /// Menampilkan notifikasi dengan judul, isi, dan payload tertentu.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  });
  /// Menjadwalkan pengingat mingguan berulang pada hari dan waktu tertentu.
  Future<void> scheduleWeeklyReminder({
    required Set<int> weekdays,
    required int hour,
    required int minute,
  });
  /// Membatalkan seluruh pengingat mingguan yang terjadwal.
  Future<void> cancelWeeklyReminders();
}

class LocalRideNotificationService implements RideNotificationService {
  /// Membuat layanan notifikasi lokal dengan plugin opsional untuk pengujian.
  LocalRideNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'ride_progress';
  static const _reminderIds = [7101, 7102, 7103, 7104, 7105, 7106, 7107];

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  /// Menginisialisasi zona waktu dan plugin notifikasi sekali saja.
  Future<void> initialize() async {
    if (_initialized) return;
    timezone_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(timezone.getLocation(localTimezone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('notification_icon'),
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
  /// Meminta izin notifikasi Android atau iOS dan mengembalikan hasilnya.
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
  /// Menampilkan notifikasi progres dengan saluran berprioritas tinggi.
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
  /// Menjadwalkan ulang pengingat untuk tiap hari yang dipilih pengguna.
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
  /// Membatalkan semua notifikasi pengingat mingguan berdasarkan id tetapnya.
  Future<void> cancelWeeklyReminders() async {
    await initialize();
    for (final id in _reminderIds) {
      await _plugin.cancel(id: id);
    }
  }
}
