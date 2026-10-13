import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/senapath_design.dart';
import '../../session/presentation/session_cubit.dart';
import 'leaderboard_cubit.dart';

class LeaderboardSettingsSection extends StatefulWidget {
  const LeaderboardSettingsSection({super.key});

  @override
  State<LeaderboardSettingsSection> createState() =>
      _LeaderboardSettingsSectionState();
}

class _LeaderboardSettingsSectionState
    extends State<LeaderboardSettingsSection> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(_loadLeaderboardAndRecords());
  }

  Future<void> _loadLeaderboardAndRecords() async {
    final sessionCubit = context.read<RideSessionCubit>();
    await sessionCubit.initialize();
    if (!mounted) return;
    context.read<LeaderboardCubit>().updateLocalRecords(
      sessionCubit.state.completedSessions,
    );
    await context.read<LeaderboardCubit>().load();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<LeaderboardCubit, LeaderboardState>(
    listenWhen: (previous, current) =>
        previous.error != current.error || previous.message != current.message,
    listener: (context, state) {
      final notice = state.error ?? state.message;
      if (notice != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(notice)));
      }
    },
    child: BlocBuilder<LeaderboardCubit, LeaderboardState>(
      builder: (context, state) {
        final settings = state.settings;
        final optedIn = settings?.isOptedIn == true;
        final busy = state.isLoading || state.isSaving;

        return SenapathCard(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.emoji_events_outlined),
                title: const Text('Ikut papan peringkat'),
                subtitle: Text(
                  optedIn
                      ? 'Nama profil dan hasil terbaikmu akan terlihat oleh peserta lain.'
                      : 'Pilihan. Aktifkan untuk membagikan hasil terbaikmu.',
                ),
                value: optedIn,
                onChanged: busy
                    ? null
                    : (enabled) => context.read<LeaderboardCubit>().saveConsent(
                        isOptedIn: enabled,
                      ),
              ),
              if (state.isLoading && settings == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    settings?.displayName == null
                        ? 'Nama di papan peringkat mengikuti nama profilmu.'
                        : 'Nama yang terlihat: ${settings!.displayName}',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'Jika ikut, nama profil serta jarak terjauh dan waktu terlama akan terlihat di papan peringkat. '
                      'Kamu bisa berhenti kapan saja; hasilmu akan dihapus dari daftar.',
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
