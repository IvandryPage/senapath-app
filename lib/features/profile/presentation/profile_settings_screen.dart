import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/senapath_design.dart';
import '../../authentication/presentation/cloud_account_cubit.dart';
import '../../../core/storage/offline_storage_manager.dart';
import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../../leaderboard/presentation/leaderboard_settings_section.dart';
import '../../session/presentation/session_cubit.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  static const _storageManager = OfflineStorageManager();
  bool _initialized = false;
  bool _loadingStorage = true;
  bool _clearingCache = false;
  OfflineStorageUsage? _usage;
  String? _storageError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    unawaited(context.read<UnitSettingsCubit>().load());
    unawaited(context.read<RideSessionCubit>().loadSyncSettings());
    unawaited(_loadStorageUsage());
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
    children: [
      _sectionHeading(
        context,
        icon: Icons.tune,
        title: 'Pengaturan umum',
        subtitle: 'Atur tampilan dan satuan jarak.',
      ),
      const SizedBox(height: 12),
      _unitSettings(),
      const SizedBox(height: 12),
      _themeModeInfo(),
      const SizedBox(height: 12),
      _biometricSettings(),
      const SizedBox(height: 12),
      _sessionSyncSettings(),
      const SizedBox(height: 12),
      SenapathCard(
        child: ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('Notifikasi latihan'),
          subtitle: const Text(
            'Kemajuan rute, titik penting, dan jadwal pengingat.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/profile/notifications'),
        ),
      ),
      const SizedBox(height: 12),
      _sectionHeading(
        context,
        icon: Icons.emoji_events_outlined,
        title: 'Papan peringkat',
        subtitle: 'Atur partisipasi dan alias yang terlihat orang lain.',
      ),
      const SizedBox(height: 12),
      const LeaderboardSettingsSection(),
      const SizedBox(height: 28),
      _sectionHeading(
        context,
        icon: Icons.storage_outlined,
        title: 'Penyimpanan',
        subtitle: 'Kelola data di ponsel dan peta tersimpan.',
      ),
      const SizedBox(height: 12),
      _storageSettings(),
    ],
  );

  Widget _sectionHeading(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) => Row(
    children: [
      CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );

  Widget _unitSettings() => BlocBuilder<UnitSettingsCubit, UnitSettingsState>(
    builder: (context, state) => SenapathCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sistem satuan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Berlaku pada peta, rekaman, ringkasan, dan riwayat.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            SegmentedButton<UnitSystem>(
              segments: const [
                ButtonSegment(
                  value: UnitSystem.metric,
                  label: Text('Metrik'),
                  icon: Icon(Icons.straighten),
                ),
                ButtonSegment(
                  value: UnitSystem.imperial,
                  label: Text('Mil & kaki'),
                  icon: Icon(Icons.square_foot),
                ),
              ],
              selected: {state.unitSystem},
              onSelectionChanged: state.isSaving
                  ? null
                  : (selection) => _saveUnitSystem(selection.first),
            ),
            if (state.isSaving)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _themeModeInfo() => SenapathCard(
    child: ListTile(
      leading: const Icon(Icons.light_mode_outlined),
      title: const Text('Tema terang'),
      subtitle: const Text(
        'Senapath menggunakan tema terang di semua kondisi.',
      ),
    ),
  );

  Widget _biometricSettings() =>
      BlocBuilder<CloudAccountCubit, CloudAccountState>(
        builder: (context, state) => SenapathCard(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: const Text('Masuk dengan sidik jari atau wajah'),
                subtitle: Text(
                  state.canUseBiometrics
                      ? state.biometricSignInEnabled
                            ? 'Aplikasi akan meminta sidik jari atau wajah saat dibuka lagi.'
                            : 'Nonaktif. Kamu perlu masuk dengan email dan kata sandi.'
                      : 'Masuk ke akun dan aktifkan sidik jari atau wajah di pengaturan perangkat.',
                ),
                value: state.biometricSignInEnabled,
                onChanged: state.isLoading || !state.isSignedIn
                    ? null
                    : context
                          .read<CloudAccountCubit>()
                          .setBiometricSignInEnabled,
              ),
              if (state.isLoading) const LinearProgressIndicator(),
              if (state.error != null || state.status != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      state.error ?? state.status!,
                      style: TextStyle(
                        color: state.error == null
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  Widget
  _sessionSyncSettings() => BlocBuilder<RideSessionCubit, RideSessionState>(
    builder: (context, state) => SenapathCard(
      child: SwitchListTile(
        title: const Text('Simpan perjalanan online otomatis'),
        subtitle: const Text(
          'Saat aktif dan akun online terhubung, perjalanan lengkap termasuk '
          'track GPS dan data sensor mentah akan dikirim otomatis serta dapat '
          'dipulihkan di perangkat lain. Saat nonaktif atau offline, data '
          'tetap tersimpan di ponsel. Mematikan opsi ini tidak menghapus '
          'salinan yang sudah tersimpan online.',
        ),
        value: state.autoSyncEnabled,
        onChanged: state.isSavingAutoSync
            ? null
            : context.read<RideSessionCubit>().setAutoSyncEnabled,
        secondary: state.isSavingAutoSync
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cloud_sync_outlined),
      ),
    ),
  );

  Widget _storageSettings() => SenapathCard(
    child: Column(
      children: [
        ListTile(
          leading: const Icon(Icons.storage_outlined),
          title: const Text('Data di ponsel'),
          subtitle: Text(
            _loadingStorage
                ? 'Menghitung…'
                : _usage == null
                ? 'Belum tersedia'
                : _formatBytes(_usage!.databaseBytes),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.map_outlined),
          title: const Text('Peta tersimpan'),
          subtitle: Text(
            _loadingStorage
                ? 'Menghitung…'
                : _usage == null
                ? 'Belum tersedia'
                : _formatBytes(_usage!.mapCacheBytes),
          ),
          trailing: IconButton(
            tooltip: 'Hapus peta tersimpan',
            onPressed:
                _usage == null || _usage!.mapCacheBytes == 0 || _clearingCache
                ? null
                : _confirmClearMapCache,
            icon: _clearingCache
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
          ),
        ),
        if (_storageError case final error?)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_loadingStorage) const LinearProgressIndicator(),
      ],
    ),
  );

  Future<void> _saveUnitSystem(UnitSystem unitSystem) async {
    try {
      await context.read<UnitSettingsCubit>().select(unitSystem);
    } catch (error) {
      if (mounted) _showMessage('Satuan tidak dapat disimpan: $error');
    }
  }

  Future<void> _loadStorageUsage() async {
    setState(() {
      _loadingStorage = true;
      _storageError = null;
    });
    try {
      final usage = await _storageManager.usage();
      if (!mounted) return;
      setState(() {
        _usage = usage;
        _loadingStorage = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingStorage = false;
        _storageError = 'Penggunaan penyimpanan tidak dapat dibaca: $error';
      });
    }
  }

  Future<void> _confirmClearMapCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => SenapathAlertDialog(
        title: const Text('Hapus peta tersimpan?'),
        content: const Text(
          'Hanya data peta yang diunduh yang akan dihapus. Perjalanan dan rute tersimpan tetap aman.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus peta'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearingCache = true);
    try {
      await _storageManager.clearMapCache();
      await _loadStorageUsage();
      if (mounted) _showMessage('Peta tersimpan berhasil dihapus.');
    } catch (error) {
      if (mounted) _showMessage('Peta tersimpan tidak dapat dihapus: $error');
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
