import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/notification_settings_repository.dart';
import '../data/ride_notification_service.dart';

class NotificationSettingsState {
  const NotificationSettingsState({
    this.settings = const RideNotificationSettings(),
    this.isLoading = false,
    this.error,
  });

  final RideNotificationSettings settings;
  final bool isLoading;
  final String? error;
}

class NotificationSettingsCubit extends Cubit<NotificationSettingsState> {
  NotificationSettingsCubit(this._repository, this._notifications)
    : super(const NotificationSettingsState());

  final NotificationSettingsRepository _repository;
  final RideNotificationService _notifications;

  Future<void> load() async {
    if (state.isLoading) return;
    emit(NotificationSettingsState(settings: state.settings, isLoading: true));
    try {
      final settings = await _repository.load();
      if (!isClosed) {
        emit(NotificationSettingsState(settings: settings));
        if (settings.remindersEnabled) await _schedule(settings);
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          NotificationSettingsState(
            settings: state.settings,
            error: 'Pengaturan notifikasi tidak dapat dibuka.',
          ),
        );
      }
    }
  }

  Future<void> update(RideNotificationSettings settings) async {
    final previous = state.settings;
    emit(NotificationSettingsState(settings: settings));
    try {
      if ((settings.remindersEnabled ||
              settings.routeProgressEnabled ||
              settings.remindersEnabled) &&
          !await _notifications.requestPermission()) {
        emit(
          NotificationSettingsState(
            settings: previous,
            error: 'Izin notifikasi belum diberikan.',
          ),
        );
        return;
      }
      await _repository.save(settings);
      if (settings.remindersEnabled) {
        await _schedule(settings);
      } else {
        await _notifications.cancelWeeklyReminders();
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          NotificationSettingsState(
            settings: previous,
            error: 'Pengaturan notifikasi gagal disimpan.',
          ),
        );
      }
    }
  }

  Future<void> _schedule(RideNotificationSettings settings) =>
      _notifications.scheduleWeeklyReminder(
        weekdays: settings.reminderWeekdays,
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
      );

  Future<void> sendRecommendation(String recommendation) async {
    try {
      if (!await _notifications.requestPermission()) {
        emit(
          NotificationSettingsState(
            settings: state.settings,
            error: 'Izin notifikasi belum diberikan.',
          ),
        );
        return;
      }
      await _notifications.show(
        id: 7500,
        title: 'Rekomendasi gowes',
        body: recommendation.length > 220
            ? '${recommendation.substring(0, 217)}...'
            : recommendation,
        payload: 'ride-coach',
      );
    } catch (_) {
      if (!isClosed) {
        emit(
          NotificationSettingsState(
            settings: state.settings,
            error: 'Rekomendasi tidak dapat dikirim ke notifikasi.',
          ),
        );
      }
    }
  }
}
