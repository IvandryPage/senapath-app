import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/senapath_design.dart';
import 'leaderboard_cubit.dart';

class LeaderboardSettingsSection extends StatefulWidget {
  const LeaderboardSettingsSection({super.key});

  @override
  State<LeaderboardSettingsSection> createState() =>
      _LeaderboardSettingsSectionState();
}

class _LeaderboardSettingsSectionState
    extends State<LeaderboardSettingsSection> {
  final _aliasController = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(context.read<LeaderboardCubit>().load());
  }

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<LeaderboardCubit, LeaderboardState>(
    listenWhen: (previous, current) =>
        previous.settings != current.settings ||
        previous.error != current.error ||
        previous.message != current.message,
    listener: (context, state) {
      if (state.settings != null &&
          _aliasController.text != (state.settings!.alias ?? '')) {
        _aliasController.text = state.settings!.alias ?? '';
      }
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
                title: const Text('Partisipasi papan peringkat'),
                subtitle: Text(
                  optedIn
                      ? 'Alias dan nilai sesi terbaik ditampilkan. Lokasi, rute, email, dan GPS mentah tidak dibagikan.'
                      : 'Opsional. Aktifkan untuk ikut peringkat mingguan.',
                ),
                value: optedIn,
                onChanged: busy
                    ? null
                    : (enabled) {
                        if (enabled && _aliasController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Isi alias publik terlebih dahulu.',
                                ),
                              ),
                            );
                          return;
                        }
                        context.read<LeaderboardCubit>().saveConsent(
                          alias: enabled ? _aliasController.text : '',
                          isOptedIn: enabled,
                        );
                      },
              ),
              if (state.isLoading && settings == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _aliasController,
                    maxLength: 24,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: 'Alias publik',
                      helperText: '3–24 karakter; gunakan nama samaran.',
                    ),
                  ),
                ),
                if (optedIn)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy
                            ? null
                            : () =>
                                  context.read<LeaderboardCubit>().saveConsent(
                                    alias: _aliasController.text,
                                    isOptedIn: true,
                                  ),
                        child: state.isSaving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Simpan alias'),
                      ),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'Gunakan alias samaran. Hanya alias dan nilai kategori yang terlihat di papan peringkat. '
                      'Menonaktifkan partisipasi akan menghapus skor Anda.',
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
