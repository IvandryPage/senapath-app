import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/theme_settings_cubit.dart';
import '../../../core/storage/offline_storage_manager.dart';
import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';

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
    unawaited(context.read<ThemeSettingsCubit>().load());
    unawaited(_loadStorageUsage());
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
    children: [
      _sectionHeading(
        context,
        icon: Icons.tune,
        title: 'Preferensi',
        subtitle: 'Sesuaikan tampilan dan satuan aktivitas.',
      ),
      const SizedBox(height: 12),
      _unitSettings(),
      const SizedBox(height: 12),
      _themeSettings(),
      const SizedBox(height: 28),
      _sectionHeading(
        context,
        icon: Icons.storage_outlined,
        title: 'Penyimpanan',
        subtitle: 'Kelola data lokal dan cache peta.',
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
        child: Icon(icon, color: Theme.of(context).colorScheme.onSecondaryContainer),
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
    builder: (context, state) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sistem satuan', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Berlaku pada peta, sesi, ringkasan, dan riwayat.',
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
                  label: Text('Imperial'),
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

  Widget _themeSettings() => BlocBuilder<ThemeSettingsCubit, ThemeSettingsState>(
    builder: (context, state) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tema tampilan', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Pilih tema sistem, terang, atau gelap.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('Sistem'),
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Terang'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Gelap'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {state.themeMode},
              onSelectionChanged: state.isSaving
                  ? null
                  : (selection) =>
                        context.read<ThemeSettingsCubit>().select(selection.first),
            ),
            if (state.isSaving)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            if (state.error case final error?) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              if (!state.isSaving)
                TextButton.icon(
                  onPressed: context.read<ThemeSettingsCubit>().load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba lagi'),
                ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _storageSettings() => Card(
    child: Column(
      children: [
        ListTile(
          leading: const Icon(Icons.storage_outlined),
          title: const Text('Database lokal'),
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
          title: const Text('Cache peta'),
          subtitle: Text(
            _loadingStorage
                ? 'Menghitung…'
                : _usage == null
                ? 'Belum tersedia'
                : _formatBytes(_usage!.mapCacheBytes),
          ),
          trailing: IconButton(
            tooltip: 'Hapus cache peta',
            onPressed: _usage == null || _usage!.mapCacheBytes == 0 || _clearingCache
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
        if (_loadingStorage)
          const LinearProgressIndicator(),
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
      builder: (context) => AlertDialog(
        title: const Text('Hapus cache peta?'),
        content: const Text(
          'Tindakan ini hanya menghapus cache peta, bukan database, '
          'rute GPX, atau sesi latihan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus cache'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearingCache = true);
    try {
      await _storageManager.clearMapCache();
      await _loadStorageUsage();
      if (mounted) _showMessage('Cache peta berhasil dihapus.');
    } catch (error) {
      if (mounted) _showMessage('Cache peta tidak dapat dihapus: $error');
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
