import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/senapath_design.dart';
import 'ride_ledger_cubit.dart';

class RideLedgerScreen extends StatefulWidget {
  const RideLedgerScreen({super.key});

  @override
  State<RideLedgerScreen> createState() => _RideLedgerScreenState();
}

class _RideLedgerScreenState extends State<RideLedgerScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(context.read<RideLedgerCubit>().load());
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<RideLedgerCubit, RideLedgerState>(
    builder: (context, state) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SenapathCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      state.isVerified == true
                          ? Icons.verified_outlined
                          : Icons.warning_amber_outlined,
                      color: state.isVerified == true
                          ? Colors.green
                          : Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.isVerified == true
                            ? 'Semua blok terverifikasi'
                            : 'Rantai belum terverifikasi',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Setiap sesi selesai menambahkan ringkasan jarak dan durasi ke rantai hash. '
                  'Data lokasi mentah tidak dimasukkan.',
                ),
                const SizedBox(height: 12),
                if (state.cloudBlockCount != null)
                  Text(
                    'Database cloud: ${state.cloudBlockCount} blok tersimpan',
                  ),
                if (state.message case final message?) ...[
                  const SizedBox(height: 8),
                  Text(message),
                ],
                OutlinedButton.icon(
                  onPressed: () => context.read<RideLedgerCubit>().verify(),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Verifikasi ulang'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed:
                      !context.read<RideLedgerCubit>().canSync ||
                          state.isSyncing ||
                          state.blocks.isEmpty
                      ? null
                      : () => _confirmSync(context),
                  icon: state.isSyncing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    state.isSyncing ? 'Menyinkronkan…' : 'Sinkronkan bukti',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Blok aktivitas (${state.blocks.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (state.blocks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Selesaikan sesi untuk membuat blok bukti pertama.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final block in state.blocks.reversed)
            SenapathCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Blok #${block.index + 1} · '
                    '${(block.distanceMeters / 1000).toStringAsFixed(2)} km · '
                    '${Duration(seconds: block.durationSeconds).inMinutes} menit',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    'Hash: ${block.hash}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  SelectableText(
                    'Sebelumnya: ${block.previousHash}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          if (state.error != null)
            Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          const Text(
            'Hash aktivitas yang disinkronkan tidak berisi GPS, nama, atau email. '
            'Database cloud menyimpan rantai hash untuk sinkronisasi akun. Ini bukan '
            'blockchain terdesentralisasi: operator database tetap mengelola data, '
            'dan hash hanya membantu mendeteksi perubahan terhadap rantai yang tersimpan.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      );
    },
  );

  Future<void> _confirmSync(BuildContext context) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Sinkronkan hash bukti?'),
        content: const Text(
          'Hash, indeks blok, waktu selesai, jarak, dan durasi sesi akan disimpan '
          'di database cloud akunmu. Koordinat GPS, nama, serta email tidak dikirim. '
          'Ini sinkronisasi ledger cloud, bukan pencatatan pada blockchain publik.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Setuju & sinkronkan'),
          ),
        ],
      ),
    );
    if (approved == true && context.mounted) {
      await context.read<RideLedgerCubit>().sync();
    }
  }
}
