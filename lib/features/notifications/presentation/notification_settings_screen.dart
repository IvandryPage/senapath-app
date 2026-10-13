import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/senapath_design.dart';
import 'notification_settings_cubit.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const _weekdays = ['Sn', 'Sl', 'Rb', 'Km', 'Jm', 'Sb', 'Mg'];
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(context.read<NotificationSettingsCubit>().load());
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<NotificationSettingsCubit, NotificationSettingsState>(
    listenWhen: (previous, current) => current.error != null,
    listener: (context, state) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.error!)));
    },
    builder: (context, state) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      final cubit = context.read<NotificationSettingsCubit>();
      final settings = state.settings;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Tetap terhubung dengan progres latihanmu.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            title: const Text('Progres GPX dan checkpoint'),
            subtitle: const Text(
              'Peringatan jarak, checkpoint dekat, dan checkpoint tercapai saat sesi aktif.',
            ),
            value: settings.routeProgressEnabled,
            onChanged: state.isSaving
                ? null
                : (enabled) => cubit.update(
                    settings.copyWith(routeProgressEnabled: enabled),
                  ),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            title: const Text('Pengingat latihan mingguan'),
            subtitle: const Text(
              'Dijadwalkan oleh perangkat dan tetap berfungsi saat aplikasi ditutup.',
            ),
            value: settings.remindersEnabled,
            onChanged: state.isSaving
                ? null
                : (enabled) => cubit.update(
                    settings.copyWith(remindersEnabled: enabled),
                  ),
          ),
          if (state.isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: LinearProgressIndicator(),
            ),
          if (state.requiresSettings) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: OutlinedButton.icon(
                onPressed: state.isSaving
                    ? null
                    : cubit.openNotificationSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Buka pengaturan notifikasi perangkat'),
              ),
            ),
          ],
          if (settings.remindersEnabled) ...[
            const SizedBox(height: 8),
            SenapathCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hari latihan',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (var day = 1; day <= 7; day++)
                        FilterChip(
                          label: Text(_weekdays[day - 1]),
                          selected: settings.reminderWeekdays.contains(day),
                          onSelected: state.isSaving
                              ? null
                              : (selected) {
                            final days = {...settings.reminderWeekdays};
                            if (selected) {
                              days.add(day);
                            } else {
                              days.remove(day);
                            }
                            if (days.isNotEmpty) {
                              unawaited(
                                cubit.update(
                                  settings.copyWith(reminderWeekdays: days),
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: state.isSaving
                        ? null
                        : () async {
                      final selected = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: settings.reminderHour,
                          minute: settings.reminderMinute,
                        ),
                      );
                      if (selected == null || !context.mounted) return;
                      await cubit.update(
                        settings.copyWith(
                          reminderHour: selected.hour,
                          reminderMinute: selected.minute,
                        ),
                          );
                        },
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      'Waktu ${TimeOfDay(hour: settings.reminderHour, minute: settings.reminderMinute).format(context)}',
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Pengingat latihan adalah notifikasi lokal terjadwal, bukan push dari server. '
            'Peringatan rute berjalan selama sesi aktif dan memerlukan izin lokasi latar belakang perangkat.',
          ),
        ],
      );
    },
  );
}
