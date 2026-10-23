import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/senapath_design.dart';
import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../../../core/validation/input_formatters.dart';
import '../../../core/validation/validators.dart';
import '../../profile/presentation/profile_cubit.dart';
import '../../session/domain/ride_session.dart';
import '../../session/presentation/session_cubit.dart';
import '../domain/cycling_team.dart';
import 'cycling_team_cubit.dart';

class CyclingTeamScreen extends StatefulWidget {
  /// Membuat layar daftar tim dengan aksi buat dan gabung.
  const CyclingTeamScreen({super.key});

  /// Membuat state untuk memuat daftar tim saat layar dibuka.
  @override
  State<CyclingTeamScreen> createState() => _CyclingTeamScreenState();
}

class _CyclingTeamScreenState extends State<CyclingTeamScreen> {
  /// Memuat daftar tim saat state pertama kali dibuat.
  @override
  void initState() {
    super.initState();
    unawaited(context.read<CyclingTeamCubit>().loadTeams());
  }

  /// Menampilkan akses akun, aksi tim, dan daftar tim pengguna.
  @override
  Widget build(BuildContext context) =>
      BlocListener<CyclingTeamCubit, CyclingTeamState>(
        listenWhen: (previous, current) =>
            previous.message != current.message && current.message != null ||
            previous.error != current.error && current.error != null,
        listener: (context, state) {
          final message = state.error ?? state.message!;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
          context.read<CyclingTeamCubit>().clearMessage();
        },
        child: BlocBuilder<CyclingTeamCubit, CyclingTeamState>(
          builder: (context, state) {
            final teamCubit = context.read<CyclingTeamCubit>();
            if (!teamCubit.isConfigured || !teamCubit.isSignedIn) {
              return _TeamAccessRequired(configured: teamCubit.isConfigured);
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Text(
                  'Buat tim atau bergabung untuk melihat perjalanan yang dibagikan anggota.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                const _PrivacyNotice(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: state.isSaving ? null : _joinTeam,
                        icon: const Icon(Icons.group_add_outlined),
                        label: const Text('Gabung pakai kode'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: state.isSaving ? null : _createTeam,
                        icon: const Icon(Icons.add),
                        label: const Text('Buat tim'),
                      ),
                    ),
                  ],
                ),
                if (state.isSaving) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                if (state.isLoading && state.teams.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.error != null && state.teams.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Column(
                      children: [
                        Text(state.error!, textAlign: TextAlign.center),
                        TextButton.icon(
                          onPressed: teamCubit.loadTeams,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  )
                else if (state.teams.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text(
                        'Kamu belum tergabung dalam tim. Buat tim baru atau '
                        'masukkan kode undangan dari ketua tim.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else ...[
                  const SizedBox(height: 24),
                  Text(
                    'Tim saya',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  for (final team in state.teams)
                    _TeamListCard(
                      team: team,
                      onTap: () => context.push('/profile/teams/${team.id}'),
                    ),
                ],
              ],
            );
          },
        ),
      );

  /// Menampilkan form nama tim lalu membuat tim untuk pengguna.
  Future<void> _createTeam() async {
    final displayName = _currentProfileDisplayName();
    if (displayName == null) return;
    final form = await _showTeamForm(join: false);
    if (form == null || !mounted) return;
    await context.read<CyclingTeamCubit>().createTeam(
      name: form.name,
      displayName: displayName,
    );
  }

  /// Menampilkan form kode undangan lalu bergabung ke tim.
  Future<void> _joinTeam() async {
    final displayName = _currentProfileDisplayName();
    if (displayName == null) return;
    final form = await _showTeamForm(join: true);
    if (form == null || !mounted) return;
    await context.read<CyclingTeamCubit>().joinTeam(
      inviteCode: form.inviteCode,
      displayName: displayName,
    );
  }

  /// Mengambil nama tampilan profil atau menampilkan pesan bila belum diatur.
  String? _currentProfileDisplayName() {
    final displayName = context
        .read<ProfileCubit>()
        .state
        .profile
        .displayName
        .trim();
    if (displayName.isNotEmpty) return displayName;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Atur nama di Edit profil sebelum membuat atau bergabung dengan tim.',
          ),
        ),
      );
    return null;
  }

  /// Menampilkan dialog form buat atau gabung tim dan mengembalikan isiannya.
  Future<_TeamFormResult?> _showTeamForm({required bool join}) {
    final nameController = TextEditingController();
    final inviteController = TextEditingController();
    final currentDisplayName = context
        .read<ProfileCubit>()
        .state
        .profile
        .displayName
        .trim();
    final formKey = GlobalKey<FormState>();

    return showDialog<_TeamFormResult>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        scrollable: true,
        title: Text(join ? 'Gabung dengan kode' : 'Buat tim'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (join)
                TextFormField(
                  controller: inviteController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    const SingleLineInputFormatter(),
                    const ForbiddenCharactersInputFormatter(),
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                    LengthLimitingTextInputFormatter(
                      InputLimits.inviteCodeMaxLength,
                    ),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Kode undangan',
                    border: OutlineInputBorder(),
                  ),
                  validator: TextValidators.inviteCode,
                )
              else
                TextFormField(
                  controller: nameController,
                  maxLength: InputLimits.teamNameMaxLength,
                  inputFormatters: const [
                    SingleLineInputFormatter(),
                    ForbiddenCharactersInputFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Nama tim',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => TextValidators.name(
                    value,
                    label: 'nama tim',
                    minLength: InputLimits.teamNameMinLength,
                    maxLength: InputLimits.teamNameMaxLength,
                    emptyMessage: 'Masukkan nama tim.',
                  ),
                ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: const Text('Nama anggota tim'),
                subtitle: Text(currentDisplayName),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(dialogContext).pop(
                _TeamFormResult(
                  name: nameController.text.trim(),
                  inviteCode: inviteController.text.trim().toUpperCase(),
                ),
              );
            },
            child: Text(join ? 'Gabung' : 'Buat tim'),
          ),
        ],
      ),
    ).whenComplete(() {
      nameController.dispose();
      inviteController.dispose();
    });
  }
}

class CyclingTeamDashboardScreen extends StatefulWidget {
  /// Membuat layar dashboard untuk tim dengan ID tertentu.
  const CyclingTeamDashboardScreen({required this.teamId, super.key});

  final String teamId;

  /// Membuat state untuk memuat dashboard tim saat layar dibuka.
  @override
  State<CyclingTeamDashboardScreen> createState() =>
      _CyclingTeamDashboardScreenState();
}

class _CyclingTeamDashboardScreenState
    extends State<CyclingTeamDashboardScreen> {
  /// Memuat dashboard tim dan sesi perjalanan saat state dibuat.
  @override
  void initState() {
    super.initState();
    unawaited(context.read<CyclingTeamCubit>().loadDashboard(widget.teamId));
    unawaited(context.read<RideSessionCubit>().initialize());
  }

  /// Menampilkan ringkasan tim, anggota, perjalanan bersama, dan aksi ketua.
  @override
  Widget build(BuildContext context) =>
      BlocListener<CyclingTeamCubit, CyclingTeamState>(
        listenWhen: (previous, current) =>
            previous.message != current.message && current.message != null ||
            previous.error != current.error && current.error != null,
        listener: (context, state) {
          final message = state.error ?? state.message!;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
          context.read<CyclingTeamCubit>().clearMessage();
        },
        child: BlocBuilder<CyclingTeamCubit, CyclingTeamState>(
          builder: (context, state) {
            final dashboard = state.dashboard;
            final metric =
                context.watch<UnitSettingsCubit>().state.unitSystem ==
                UnitSystem.metric;
            if (state.isLoading && dashboard == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null && dashboard == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.error!, textAlign: TextAlign.center),
                      TextButton.icon(
                        onPressed: () => context
                            .read<CyclingTeamCubit>()
                            .loadDashboard(widget.teamId),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (dashboard == null) return const SizedBox.shrink();
            final myUserId = context.read<CyclingTeamCubit>().currentUserId;
            final ownMember = dashboard.members
                .where((member) => member.userId == myUserId)
                .firstOrNull;
            final sharedSessionIds = dashboard.sharedSessions
                .where((ride) => ride.userId == myUserId)
                .map((ride) => ride.sessionId)
                .toSet();
            final canLeaveTeam =
                ownMember?.isManager != true ||
                dashboard.members.any(
                  (member) => member.isManager && member.userId != myUserId,
                );

            return RefreshIndicator(
              onRefresh: () =>
                  context.read<CyclingTeamCubit>().loadDashboard(widget.teamId),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  Text(
                    dashboard.team.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    '${dashboard.members.length} anggota · '
                    '${dashboard.team.isManager ? 'Ketua tim' : 'Anggota'}',
                  ),
                  if (dashboard.team.isManager) ...[
                    const SizedBox(height: 12),
                    _InviteCodeCard(code: dashboard.team.inviteCode),
                  ],
                  const SizedBox(height: 16),
                  _TeamSummaryCards(dashboard: dashboard, metric: metric),
                  const SizedBox(height: 20),
                  Text(
                    'Ringkasan anggota',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  for (final member in dashboard.members)
                    _MemberSummaryCard(
                      member: member,
                      sessions: dashboard.sessionsFor(member.userId),
                      metric: metric,
                      onSetRole:
                          dashboard.team.isManager && member.userId != myUserId
                          ? (role) =>
                                context.read<CyclingTeamCubit>().setMemberRole(
                                  widget.teamId,
                                  member.userId,
                                  role,
                                )
                          : null,
                      onUnshare: member.userId == myUserId
                          ? (session) =>
                                context.read<CyclingTeamCubit>().unshareSession(
                                  widget.teamId,
                                  session.sessionId,
                                )
                          : null,
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Bagikan perjalanan selesai',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pilih perjalanan yang ingin dibagikan. Titik lokasi dan '
                    'rute tidak akan ikut dibagikan.',
                  ),
                  const SizedBox(height: 8),
                  if (ownMember == null)
                    const SizedBox.shrink()
                  else
                    _ShareableSessions(
                      sessions: context
                          .watch<RideSessionCubit>()
                          .state
                          .completedSessions,
                      sharedSessionIds: sharedSessionIds,
                      canSync: context
                          .watch<RideSessionCubit>()
                          .canSyncSessions,
                      metric: metric,
                      onShare: _confirmAndShare,
                    ),
                  const SizedBox(height: 16),
                  if (canLeaveTeam)
                    OutlinedButton.icon(
                      onPressed: state.isSaving ? null : _leaveTeam,
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Keluar dari tim'),
                    ),
                  if (dashboard.team.isManager) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: state.isSaving ? null : _deleteTeam,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Hapus tim'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );

  /// Meminta konfirmasi lalu membagikan ringkasan sesi ke tim.
  Future<void> _confirmAndShare(RideSessionSnapshot session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Bagikan ringkasan perjalanan?'),
        content: const Text(
          'Anggota tim dapat melihat waktu, durasi, jarak, dan elevasi perjalanan ini. '
          'Titik lokasi dan rute tidak dibagikan. Ringkasan juga akan disimpan '
          'ke akun online-mu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Setuju dan bagikan'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await context.read<RideSessionCubit>().syncSummary(
      session.id,
      consented: true,
      shareWithTeamId: widget.teamId,
    );
    if (!mounted) return;
    final message =
        context.read<RideSessionCubit>().state.message ??
        'Perjalanan belum bisa dibagikan.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    await context.read<CyclingTeamCubit>().loadDashboard(widget.teamId);
  }

  /// Meminta konfirmasi, keluar dari tim, dan kembali bila sudah tidak diikuti.
  Future<void> _leaveTeam() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Keluar dari tim?'),
        content: const Text(
          'Ringkasan perjalanan yang pernah dibagikan tidak akan terlihat lagi '
          'oleh tim ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await context.read<CyclingTeamCubit>().leaveTeam(widget.teamId);
    if (mounted &&
        !context.read<CyclingTeamCubit>().state.teams.any(
          (team) => team.id == widget.teamId,
        )) {
      context.pop();
    }
  }

  /// Meminta konfirmasi, menghapus tim, dan kembali setelah berhasil.
  Future<void> _deleteTeam() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Hapus tim secara permanen?'),
        content: const Text(
          'Tim dan keanggotaannya akan dihapus untuk semua anggota. '
          'Tautan ringkasan perjalanan yang dibagikan ke tim ikut dihapus, '
          'tetapi riwayat perjalanan pribadi tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            child: const Text('Hapus tim'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final cubit = context.read<CyclingTeamCubit>();
    await cubit.deleteTeam(widget.teamId);
    if (mounted &&
        cubit.state.message?.startsWith('Tim berhasil dihapus') == true) {
      context.pop();
    }
  }
}

class _TeamAccessRequired extends StatelessWidget {
  /// Membuat pesan akses tim dengan status konfigurasi layanan.
  const _TeamAccessRequired({required this.configured});

  final bool configured;

  /// Menampilkan ikon, pesan, dan tombol masuk sesuai status layanan.
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            configured ? Icons.account_circle_outlined : Icons.cloud_off,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            configured
                ? 'Masuk ke akun Senapath untuk membuat atau bergabung dengan tim.'
                : 'Fitur tim belum tersedia saat ini.',
            textAlign: TextAlign.center,
          ),
          if (configured) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.push('/account'),
              child: const Text('Masuk atau daftar'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _PrivacyNotice extends StatelessWidget {
  /// Membuat kartu informasi privasi data perjalanan tim.
  const _PrivacyNotice();

  /// Menampilkan penjelasan singkat tentang data yang dibagikan ke tim.
  @override
  Widget build(BuildContext context) => SenapathCard(
    child: const Padding(
      padding: EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Anggota hanya bisa melihat ringkasan perjalanan yang kamu pilih '
              'untuk dibagikan. Lokasi langsung dan titik lokasi rinci tidak dibagikan.',
            ),
          ),
        ],
      ),
    ),
  );
}

class _TeamListCard extends StatelessWidget {
  /// Membuat kartu ringkas tim dengan aksi saat diketuk.
  const _TeamListCard({required this.team, required this.onTap});

  final CyclingTeam team;
  final VoidCallback onTap;

  /// Menampilkan nama, jumlah anggota, peran, dan ikon navigasi tim.
  @override
  Widget build(BuildContext context) => SenapathCard(
    onTap: onTap,
    child: ListTile(
      leading: CircleAvatar(
        child: Icon(
          team.isManager ? Icons.groups_2_outlined : Icons.group_outlined,
        ),
      ),
      title: Text(team.name),
      subtitle: Text(
        '${team.memberCount} anggota · '
        '${team.isManager ? 'Ketua tim' : 'Anggota'}',
      ),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class _InviteCodeCard extends StatelessWidget {
  /// Membuat kartu kode undangan yang dapat disalin.
  const _InviteCodeCard({required this.code});

  final String code;

  /// Menampilkan kode undangan dengan tombol salin ke papan klip.
  @override
  Widget build(BuildContext context) => SenapathCard(
    child: ListTile(
      leading: const Icon(Icons.vpn_key_outlined),
      title: const Text('Kode undangan'),
      subtitle: SelectableText(
        code,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 2),
      ),
      trailing: IconButton(
        tooltip: 'Salin kode undangan',
        onPressed: () {
          Clipboard.setData(ClipboardData(text: code));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kode undangan disalin.')),
          );
        },
        icon: const Icon(Icons.copy_outlined),
      ),
    ),
  );
}

class _TeamSummaryCards extends StatelessWidget {
  /// Membuat deretan kartu ringkasan statistik tim.
  const _TeamSummaryCards({required this.dashboard, required this.metric});

  final CyclingTeamDashboard dashboard;
  final bool metric;

  /// Menampilkan metrik perjalanan, jarak, durasi, kecepatan, dan elevasi.
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _MetricCard(
        label: 'Perjalanan dibagikan',
        value: '${dashboard.sharedSessions.length}',
        icon: Icons.directions_bike_outlined,
      ),
      _MetricCard(
        label: 'Jarak tim',
        value: _formatDistance(dashboard.totalDistanceMeters, metric),
        icon: Icons.route_outlined,
      ),
      _MetricCard(
        label: 'Durasi aktif',
        value: _durationLabel(dashboard.totalDurationSeconds),
        icon: Icons.timer_outlined,
      ),
      _MetricCard(
        label: 'Kecepatan rata-rata',
        value: dashboard.totalDurationSeconds == 0
            ? '—'
            : _formatSpeed(
                dashboard.totalDistanceMeters / dashboard.totalDurationSeconds,
                metric,
              ),
        icon: Icons.speed_outlined,
      ),
      _MetricCard(
        label: 'Elevasi naik',
        value: '${dashboard.totalElevationGainMeters.toStringAsFixed(0)} m',
        icon: Icons.terrain_outlined,
      ),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  /// Membuat kartu metrik dengan label, nilai, dan ikon.
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  /// Menampilkan ikon, nilai metrik, dan labelnya dalam kartu berukuran tetap.
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 156,
    child: SenapathCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _MemberSummaryCard extends StatelessWidget {
  /// Membuat kartu anggota dengan ringkasan sesi dan aksi peran atau tarik.
  const _MemberSummaryCard({
    required this.member,
    required this.sessions,
    required this.metric,
    this.onSetRole,
    this.onUnshare,
  });

  final CyclingTeamMember member;
  final List<TeamRideSummary> sessions;
  final bool metric;
  final ValueChanged<String>? onSetRole;
  final ValueChanged<TeamRideSummary>? onUnshare;

  /// Menampilkan profil anggota, total sesi, dan daftar perjalanan terbarunya.
  @override
  Widget build(BuildContext context) {
    final distance = sessions.fold<double>(
      0,
      (sum, session) => sum + session.distanceMeters,
    );
    final duration = sessions.fold<int>(
      0,
      (sum, session) => sum + session.durationSeconds,
    );
    return SenapathCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    member.displayName.isEmpty
                        ? '?'
                        : member.displayName.characters.first.toUpperCase(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(member.isManager ? 'Ketua tim' : 'Anggota'),
                      Text(
                        'Level ${member.riderLevel} · ${member.riderStyle.label}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${sessions.length} perjalanan'),
                    Text(_formatDistance(distance, metric)),
                    if (duration > 0) Text('Aktif ${_durationLabel(duration)}'),
                  ],
                ),
                if (onSetRole != null)
                  PopupMenuButton<String>(
                    tooltip: 'Kelola peran ${member.displayName}',
                    onSelected: onSetRole,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: member.isManager ? 'member' : 'manager',
                        child: Text(
                          member.isManager
                              ? 'Jadikan anggota'
                              : 'Jadikan ketua',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (sessions.isNotEmpty) ...[
              const Divider(height: 20),
              for (final session in sessions.take(3))
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${DateFormat('d MMM yyyy').format(session.startedAt.toLocal())}'
                          ' · ${_formatDistance(session.distanceMeters, metric)}'
                          ' · ${_durationLabel(session.durationSeconds)}',
                        ),
                      ),
                    ),
                    if (onUnshare != null)
                      IconButton(
                        tooltip: 'Tarik ringkasan dari tim',
                        onPressed: () => onUnshare!(session),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                  ],
                ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Belum membagikan ringkasan perjalanan.'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShareableSessions extends StatelessWidget {
  /// Membuat daftar sesi selesai yang dapat dibagikan ke tim.
  const _ShareableSessions({
    required this.sessions,
    required this.sharedSessionIds,
    required this.canSync,
    required this.metric,
    required this.onShare,
  });

  final List<RideSessionSnapshot> sessions;
  final Set<String> sharedSessionIds;
  final bool canSync;
  final bool metric;
  final ValueChanged<RideSessionSnapshot> onShare;

  /// Menampilkan tiap sesi selesai dengan tombol bagikan atau status dibagikan.
  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Belum ada perjalanan selesai yang bisa dibagikan.'),
      );
    }
    return BlocBuilder<RideSessionCubit, RideSessionState>(
      builder: (context, state) => Column(
        children: [
          for (final session in sessions)
            SenapathCard(
              child: ListTile(
                title: Text(
                  session.title.isNotEmpty ? session.title : 'Perjalanan',
                ),
                subtitle: Text(
                  '${DateFormat('d MMM yyyy').format(session.startedAt.toLocal())}'
                  ' · ${_formatDistance(session.distanceMeters, metric)}',
                ),
                trailing: sharedSessionIds.contains(session.id)
                    ? const Chip(label: Text('Dibagikan'))
                    : IconButton(
                        tooltip: canSync
                            ? 'Bagikan ringkasan perjalanan ke tim'
                            : 'Masuk ke akun untuk membagikan',
                        onPressed: !canSync || state.syncingSessionId != null
                            ? null
                            : () => onShare(session),
                        icon: const Icon(Icons.share_outlined),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TeamFormResult {
  /// Menampung hasil input form buat atau gabung tim.
  const _TeamFormResult({required this.name, required this.inviteCode});

  final String name;
  final String inviteCode;
}

  /// Memformat durasi detik menjadi label jam dan menit.
  String _durationLabel(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '$minutes mnt';
  return '$hours jam $minutes mnt';
}

  /// Mengonversi meter ke kilometer atau mil sesuai sistem unit.
  String _formatDistance(double meters, bool metric) => metric
    ? '${(meters / 1000).toStringAsFixed(1)} km'
    : '${(meters / 1609.344).toStringAsFixed(1)} mi';

  /// Mengonversi meter per detik ke km/jam atau mph sesuai sistem unit.
  String _formatSpeed(double metersPerSecond, bool metric) {
  final speed = metersPerSecond * (metric ? 3.6 : 2.236936);
  return '${speed.toStringAsFixed(1)} ${metric ? 'km/jam' : 'mph'}';
}
