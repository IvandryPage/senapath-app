import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../session/domain/ride_session.dart';
import '../domain/leaderboard_models.dart';
import 'leaderboard_cubit.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({this.summary, super.key});

  final RideSessionSummary? summary;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _aliasController = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    context.read<LeaderboardCubit>().load();
  }

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LeaderboardCubit, LeaderboardState>(
      listenWhen: (previous, current) =>
          previous.settings != current.settings ||
          previous.error != current.error ||
          previous.message != current.message,
      listener: (context, state) {
        if (state.settings != null) {
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
          final cubit = context.read<LeaderboardCubit>();
          final settings = state.settings;
          final summary = widget.summary;
          final canSubmit = summary != null &&
              summary.session.status == RideSessionStatus.completed &&
              summary.session.syncStatus == 'synced' &&
              settings?.isOptedIn == true &&
              !state.isSaving;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                'Peringkat mingguan bersepeda · pekan berjalan UTC',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Peringkat memakai durasi aktif terpanjang dan jarak terjauh '
                'dari satu sesi selesai. Skor berasal dari ringkasan yang '
                'dikirim pengguna dan tidak diverifikasi independen.',
              ),
              const SizedBox(height: 8),
              Text(
                'Hanya alias dan nilai kategori yang ditampilkan. Lokasi, '
                'rute, email, dan telemetri mentah tidak dipublikasikan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Partisipasi dan privasi',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        settings?.isOptedIn == true
                            ? 'Partisipasi aktif. Alias Anda terlihat pada '
                                'peringkat mingguan.'
                            : 'Leaderboard bersifat opsional. Anda dapat '
                                'menarik partisipasi dan menghapus skor kapan saja.',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _aliasController,
                        maxLength: 24,
                        decoration: const InputDecoration(
                          labelText: 'Alias publik',
                          helperText: '3–24 karakter; tanpa nama/email wajib.',
                        ),
                      ),
                      FilledButton(
                        onPressed: state.isSaving || state.isLoading
                            ? null
                            : () => cubit.saveConsent(
                                alias: _aliasController.text,
                                isOptedIn: true,
                              ),
                        child: Text(
                          settings?.isOptedIn == true
                              ? 'Simpan alias'
                              : 'Aktifkan partisipasi',
                        ),
                      ),
                      if (settings?.isOptedIn == true) ...[
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: state.isSaving
                              ? null
                              : () => cubit.saveConsent(
                                  alias: '',
                                  isOptedIn: false,
                                ),
                          child: const Text('Keluar dan hapus skor saya'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (summary != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Sesi terpilih',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          summary.session.syncStatus == 'synced'
                              ? 'Ringkasan tersinkron; hanya durasi dan jarak '
                                  'akan dipakai.'
                              : 'Sinkronkan ringkasan sesi terlebih dahulu. '
                                  'Koordinat dan telemetri tidak dikirim ke leaderboard.',
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: canSubmit
                              ? () => cubit.submitSession(summary.session.id)
                              : null,
                          icon: state.isSaving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.leaderboard_outlined),
                          label: const Text('Kirim skor sesi ini'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Durasi aktif'),
                    selected: state.category == LeaderboardCategory.duration,
                    onSelected: state.isLoading
                        ? null
                        : (_) => cubit.selectCategory(
                            LeaderboardCategory.duration,
                          ),
                  ),
                  ChoiceChip(
                    label: const Text('Jarak'),
                    selected: state.category == LeaderboardCategory.distance,
                    onSelected: state.isLoading
                        ? null
                        : (_) => cubit.selectCategory(
                            LeaderboardCategory.distance,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (state.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (state.error != null)
                OutlinedButton.icon(
                  onPressed: cubit.load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba lagi'),
                )
              else if (settings?.isOptedIn != true)
                const Text('Aktifkan partisipasi untuk melihat peringkat.')
              else if (state.entries.isEmpty)
                const Text('Belum ada skor untuk kategori ini pada pekan ini.')
              else
                for (final entry in state.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text('${entry.rank}')),
                    title: Text(entry.alias),
                    trailing: Text(_formatScore(entry, state.category)),
                  ),
            ],
          );
        },
      ),
    );
  }

  String _formatScore(LeaderboardEntry entry, LeaderboardCategory category) {
    if (category == LeaderboardCategory.distance) {
      return '${(entry.score / 1000).toStringAsFixed(1)} km';
    }
    final seconds = entry.score.round();
    final hours = seconds ~/ 3600;
    final minutes = seconds % 3600 ~/ 60;
    return hours > 0
        ? '${hours}j ${minutes}m'
        : '${minutes}m ${seconds % 60}d';
  }
}
