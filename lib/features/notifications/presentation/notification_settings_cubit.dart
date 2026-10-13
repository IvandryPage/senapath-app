import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/notification_settings_repository.dart';
import '../data/ride_notification_service.dart';

class NotificationSettingsState {
  const NotificationSettingsState({
    this.settings = const RideNotificationSettings(),
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.requiresSettings = false,
  });

  final RideNotificationSettings settings;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final bool requiresSettings;
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
                  error: 'Pengingat tersimpan, tetapi jadwalnya tidak dapat dipulihkan. Periksa izin notifikasi.',
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
            error: 'Pengaturan notifikasi tidak dapat dibuka. Coba lagi.',
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
              requiresSettings: true,
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
    } catch (error) {
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
        emit(
          NotificationSettingsState(
            settings: previous,
            error: rollbackError == null
                ? 'Pengaturan notifikasi tidak dapat disimpan. '
                      'Detail: ${_errorDetails(error)}'
                : 'Pengaturan tidak dapat disimpan dan setelan sebelumnya '
                      'belum pulih sepenuhnya. Detail: ${_errorDetails(error)}',
          ),
        );
      }
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      final opened = await openAppSettings();
      if (!opened && !isClosed) {
        emit(
          NotificationSettingsState(
            settings: state.settings,
            error: 'Pengaturan notifikasi perangkat tidak dapat dibuka.',
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          NotificationSettingsState(
            settings: state.settings,
            error: 'Pengaturan notifikasi ponsel tidak dapat dibuka. Coba dari menu Setelan.',
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

  String _errorDetails(Object error) {
    if (error is PlatformException) {
      final message = error.message;
      return message == null || message.isEmpty
          ? error.code
          : '${error.code}: $message';
    }
    return error.toString();
  }

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
    } catch (error) {
      if (!isClosed) {
        emit(
          NotificationSettingsState(
            settings: state.settings,
            error: 'Rekomendasi tidak dapat dikirim ke notifikasi: $error',
          ),
        );
      }
    }
  }
}
