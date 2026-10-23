import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/senapath_design.dart';
import '../domain/ride_ledger_anchor.dart';
import '../domain/ride_ledger_block.dart';
import 'ride_ledger_cubit.dart';

/// Layar tampilan buku besar bukti perjalanan.
class RideLedgerScreen extends StatefulWidget {
  /// Membuat layar buku besar bukti perjalanan.
  const RideLedgerScreen({super.key});

  /// Membuat state untuk layar buku besar.
  @override
  State<RideLedgerScreen> createState() => _RideLedgerScreenState();
}

/// State untuk layar buku besar bukti perjalanan.
class _RideLedgerScreenState extends State<RideLedgerScreen> {
  bool _loaded = false;
  final Set<String> _visibleHashSessionIds = {};

  /// Memuat data buku besar saat dependensi berubah.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(context.read<RideLedgerCubit>().load());
  }

  /// Membangun tampilan buku besar bukti perjalanan.
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
          _buildAnchorCard(context, state),
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
            'Hash membantu mengetahui jika data bukti berubah. Salinan online '
            'disimpan di akun Senapath; hanya head hash terbaru yang dapat '
            'dicatat ke blockchain publik atas persetujuanmu.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      );
    },
  );

  /// Membangun kartu tampilan blok bukti perjalanan.
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

  /// Membangun kartu tampilan anchor blockchain.
  Widget _buildAnchorCard(BuildContext context, RideLedgerState state) {
    final cubit = context.read<RideLedgerCubit>();
    final textTheme = Theme.of(context).textTheme;
    return SenapathCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Catatan blockchain',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Segarkan status',
                onPressed: cubit.canSync ? cubit.refreshAnchors : null,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Head hash ledger dicatat ke ${state.chain?.name ?? 'blockchain EVM'} '
            'lewat transaksi publik yang bisa diperiksa di explorer. Hanya kode '
            'hash dan jumlah bukti yang ditulis, tanpa lokasi atau identitas.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                !cubit.canSync ||
                    state.isAnchoring ||
                    state.isSyncing ||
                    state.blocks.isEmpty ||
                    state.isVerified != true
                ? null
                : () => _confirmAnchor(context),
            icon: state.isAnchoring
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.publish_outlined),
            label: Text(
              state.isAnchoring ? 'Mengirim…' : 'Catat ke blockchain',
            ),
          ),
          if (!cubit.canSync)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Masuk ke akun online untuk memakai fitur ini.',
                style: textTheme.bodySmall,
              ),
            ),
          for (final anchor in state.anchors) ...[
            const Divider(height: 24),
            _buildAnchorTile(context, state, anchor),
          ],
        ],
      ),
    );
  }

  /// Membangun item tampilan anchor blockchain.
  Widget _buildAnchorTile(
    BuildContext context,
    RideLedgerState state,
    RideLedgerAnchor anchor,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final chain = state.chain;
    final txHash = anchor.txHash;
    final verification = state.verifications[anchor.id];
    final verifying = state.verifyingAnchorId == anchor.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${anchor.blockCount} bukti · '
          '${anchor.isConfirmed ? 'Terkonfirmasi (blok ${anchor.blockNumber})' : 'Menunggu konfirmasi'}',
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (txHash != null) ...[
          const SizedBox(height: 4),
          SelectableText('Tx: $txHash', style: textTheme.bodySmall),
        ],
        const SizedBox(height: 4),
        SelectableText('Head: ${anchor.headHash}', style: textTheme.bodySmall),
        if (verification != null) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                verification.status == AnchorVerificationStatus.verified
                    ? Icons.verified_outlined
                    : Icons.info_outline,
                size: 18,
                color: switch (verification.status) {
                  AnchorVerificationStatus.verified => Colors.green,
                  AnchorVerificationStatus.mismatch => Theme.of(
                    context,
                  ).colorScheme.error,
                  _ => null,
                },
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(verification.detail, style: textTheme.bodySmall),
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: verifying || chain == null || txHash == null
                  ? null
                  : () => context.read<RideLedgerCubit>().verifyAnchor(anchor),
              icon: verifying
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fact_check_outlined),
              label: const Text('Verifikasi via RPC'),
            ),
            if (chain != null && txHash != null)
              TextButton.icon(
                onPressed: () => launchUrl(
                  chain.txUrl(txHash),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Buka di explorer'),
              ),
          ],
        ),
      ],
    );
  }

  /// Menampilkan konfirmasi pencatatan ke blockchain.
  Future<void> _confirmAnchor(BuildContext context) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Catat ke blockchain publik?'),
        content: const Text(
          'Head hash terbaru dan jumlah bukti akan ditulis ke blockchain '
          'publik dan tidak dapat dihapus. Ledger juga disinkronkan ke akun '
          'online. Titik lokasi, nama, dan email tidak dikirim.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ya, catat'),
          ),
        ],
      ),
    );
    if (approved == true && context.mounted) {
      await context.read<RideLedgerCubit>().anchor();
    }
  }

  /// Menampilkan konfirmasi penyimpanan salinan online.
  Future<void> _confirmSync(BuildContext context) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Simpan salinan bukti online?'),
        content: const Text(
          'Hash, waktu selesai, jarak, dan durasi akan disimpan di akun online-mu. '
          'Titik lokasi, nama, dan email tidak dikirim.',
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
