import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/notification_settings_repository.dart';
import '../data/ride_notification_service.dart';

class NotificationSettingsState {
  const NotificationSettingsState({
    this.settings = const RideNotificationSettings(),
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final RideNotificationSettings settings;
  final bool isLoading;
  final bool isSaving;
  final String? error;
}

class NotificationSettingsCubit extends Cubit<NotificationSettingsState> {
  NotificationSettingsCubit(this._repository, this._notifications)
    : super(const NotificationSettingsState());

  final NotificationSettingsRepository _repository;
  final RideNotificationService _notifications;

  Future<void> load() async {
    if (state.isLoading || state.isSaving) return;
    emit(NotificationSettingsState(settings: state.settings, isLoading: true));
    try {
      final settings = await _repository.load();
      if (!isClosed) {
        emit(NotificationSettingsState(settings: settings));
        if (settings.remindersEnabled) {
          try {
            await _schedule(settings);
          } catch (_) {
            if (!isClosed) {
              emit(
                NotificationSettingsState(
                  settings: settings,
                  error: 'Pengingat tersimpan, tetapi jadwal notifikasi gagal dipulihkan.',
                ),
              );
            }
          }
        }
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
    if (state.isSaving || state.isLoading) return;
    final previous = state.settings;
    final needsPermission =
        settings.remindersEnabled || settings.routeProgressEnabled;
    emit(NotificationSettingsState(settings: settings, isSaving: true));
    try {
      if (needsPermission && !await _notifications.requestPermission()) {
        if (!isClosed) {
          emit(
            NotificationSettingsState(
              settings: previous,
              error: 'Izin notifikasi belum diberikan.',
            ),
          );
        }
        return;
      }
      await _repository.save(settings);
      if (settings.remindersEnabled) {
        await _schedule(settings);
      } else {
        await _notifications.cancelWeeklyReminders();
      }
      if (!isClosed) emit(NotificationSettingsState(settings: settings));
    } catch (_) {
      if (!isClosed) {
        String? rollbackError;
        try {
          await _repository.save(previous);
          if (previous.remindersEnabled) {
            await _schedule(previous);
          } else {
            await _notifications.cancelWeeklyReminders();
          }
        } catch (_) {
          rollbackError =
              ' Setelan sebelumnya tidak dapat dipulihkan sepenuhnya.';
        }
        emit(NotificationSettingsState(
          settings: previous,
          error: 'Pengaturan notifikasi gagal disimpan.$rollbackError',
        ));
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
    if (recommendation.trim().isEmpty) {
      if (!isClosed) {
        emit(
          NotificationSettingsState(
            settings: state.settings,
            error: 'Rekomendasi kosong dan tidak dapat dikirim.',
          ),
        );
      }
      return;
    }
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
