import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/senapath_design.dart';
import '../domain/ride_ledger_block.dart';
import 'ride_ledger_cubit.dart';

class RideLedgerScreen extends StatefulWidget {
  const RideLedgerScreen({super.key});

  @override
  State<RideLedgerScreen> createState() => _RideLedgerScreenState();
}

class _RideLedgerScreenState extends State<RideLedgerScreen> {
  bool _loaded = false;
  final Set<String> _visibleHashSessionIds = {};

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
                            ? 'Semua kode bukti cocok'
                            : 'Kode bukti perlu diperiksa',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hash adalah kode pemeriksaan yang dibuat dari jarak dan durasi perjalanan. '
                  'Titik lokasi tidak disertakan.',
                ),
                const SizedBox(height: 12),
                if (state.cloudBlockCount != null)
                  Text(
                    'Salinan online: ${state.cloudBlockCount} bukti tersimpan',
                  ),
                if (state.message case final message?) ...[
                  const SizedBox(height: 8),
                  Text(message),
                ],
                OutlinedButton.icon(
                  onPressed: () => context.read<RideLedgerCubit>().verify(),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Periksa bukti lagi'),
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
                    state.isSyncing ? 'Menyimpan…' : 'Simpan salinan online',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Bukti perjalanan (${state.blocks.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (state.blocks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Selesaikan perjalanan untuk membuat bukti pertama.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final block in state.blocks.reversed)
            _buildBlockCard(context, block),
          if (state.error != null)
            Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          const Text(
            'Hash yang disimpan online tidak memuat titik lokasi, nama, atau email. '
            'Hash membantu mengetahui jika data bukti berubah. Salinannya disimpan '
            'di akun online Senapath, bukan di blockchain publik.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      );
    },
  );

  Widget _buildBlockCard(BuildContext context, RideLedgerBlock block) {
    final showHashes = _visibleHashSessionIds.contains(block.sessionId);
    return SenapathCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bukti #${block.index + 1} · '
                  '${(block.distanceMeters / 1000).toStringAsFixed(2)} km · '
                  '${Duration(seconds: block.durationSeconds).inMinutes} menit',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: showHashes ? 'Sembunyikan hash' : 'Tampilkan hash',
                onPressed: () {
                  setState(() {
                    if (showHashes) {
                      _visibleHashSessionIds.remove(block.sessionId);
                    } else {
                      _visibleHashSessionIds.add(block.sessionId);
                    }
                  });
                },
                icon: Icon(
                  showHashes
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ],
          ),
          Text(
            'ID perjalanan: ${block.sessionId}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (showHashes) ...[
            SelectableText(
              'Hash: ${block.hash}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SelectableText(
              'Sebelumnya: ${block.previousHash}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else
            Text(
              'Hash disembunyikan',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Future<void> _confirmSync(BuildContext context) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Simpan salinan bukti online?'),
        content: const Text(
          'Hash, waktu selesai, jarak, dan durasi akan disimpan di akun online-mu. '
          'Titik lokasi, nama, dan email tidak dikirim. Bukti disimpan di akun online, '
          'bukan di blockchain publik.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ya, simpan'),
          ),
        ],
      ),
    );
    if (approved == true && context.mounted) {
      await context.read<RideLedgerCubit>().sync();
    }
  }
}
