import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/senapath_design.dart';
import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../../authentication/presentation/cloud_account_cubit.dart';
import '../../profile/presentation/profile_cubit.dart';
import '../../session/domain/ride_session.dart';
import '../../session/presentation/session_cubit.dart';
import '../domain/cycling_team.dart';
import 'cycling_team_cubit.dart';

class CyclingTeamScreen extends StatefulWidget {
  const CyclingTeamScreen({super.key});

  @override
  State<CyclingTeamScreen> createState() => _CyclingTeamScreenState();
}

class _CyclingTeamScreenState extends State<CyclingTeamScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<CyclingTeamCubit>().loadTeams());
  }

  @override
  Widget build(BuildContext context) => BlocListener<CyclingTeamCubit,
      CyclingTeamState>(
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
              'Kelola tim dan lihat ringkasan perjalanan anggota yang dibagikan.',
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
                    label: const Text('Gabung tim'),
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

  Future<void> _createTeam() async {
    final form = await _showTeamForm(join: false);
    if (form == null || !mounted) return;
    await context.read<CyclingTeamCubit>().createTeam(
      name: form.name,
      displayName: form.displayName,
    );
  }

  Future<void> _joinTeam() async {
    final form = await _showTeamForm(join: true);
    if (form == null || !mounted) return;
    await context.read<CyclingTeamCubit>().joinTeam(
      inviteCode: form.inviteCode,
      displayName: form.displayName,
    );
  }

  Future<_TeamFormResult?> _showTeamForm({required bool join}) {
    final nameController = TextEditingController();
    final inviteController = TextEditingController();
    final currentDisplayName = context
        .read<ProfileCubit>()
        .state
        .profile
        .displayName
        .trim();
    final email = context.read<CloudAccountCubit>().state.email;
    final displayNameController = TextEditingController(
      text: currentDisplayName.isNotEmpty
          ? currentDisplayName
          : email?.split('@').first ?? '',
    );
    final formKey = GlobalKey<FormState>();

    return showDialog<_TeamFormResult>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                  decoration: const InputDecoration(
                    labelText: 'Kode undangan',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Masukkan kode undangan.'
                      : null,
                )
              else
                TextFormField(
                  controller: nameController,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Nama tim',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'Nama tim minimal 2 karakter.'
                      : null,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: displayNameController,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Nama yang terlihat oleh anggota tim',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Masukkan nama tampilan.'
                    : null,
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
                  displayName: displayNameController.text.trim(),
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
      displayNameController.dispose();
    });
  }
}

class CyclingTeamDashboardScreen extends StatefulWidget {
  const CyclingTeamDashboardScreen({required this.teamId, super.key});

  final String teamId;

  @override
  State<CyclingTeamDashboardScreen> createState() =>
      _CyclingTeamDashboardScreenState();
}

class _CyclingTeamDashboardScreenState
    extends State<CyclingTeamDashboardScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<CyclingTeamCubit>().loadDashboard(widget.teamId));
    unawaited(context.read<RideSessionCubit>().initialize());
  }

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
            final myUserId = context
                .read<CyclingTeamCubit>()
                .currentUserId;
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
              onRefresh: () => context
                  .read<CyclingTeamCubit>()
                  .loadDashboard(widget.teamId),
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
                      onSetRole: dashboard.team.isManager &&
                              member.userId != myUserId
                          ? (role) => context
                                .read<CyclingTeamCubit>()
                                .setMemberRole(
                                  widget.teamId,
                                  member.userId,
                                  role,
                                )
                          : null,
                      onUnshare: member.userId == myUserId
                          ? (session) => context
                                .read<CyclingTeamCubit>()
                                .unshareSession(widget.teamId, session.sessionId)
                          : null,
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Bagikan sesi selesai',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pilih sesi yang ingin dibagikan ke tim. Lokasi GPS dan '
                    'jejak rute tidak akan dibagikan.',
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
                ],
              ),
            );
          },
        ),
      );

  Future<void> _confirmAndShare(RideSessionSnapshot session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bagikan ringkasan sesi?'),
        content: const Text(
          'Anggota tim dapat melihat waktu, durasi, jarak, elevasi, dan jumlah '
          'sampel sesi ini. Titik GPS, lokasi, dan rute tidak dibagikan. '
          'Sesi ini juga akan disinkronkan ke akun cloud milikmu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Setujui & bagikan'),
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
        'Tidak dapat membagikan sesi.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    await context.read<CyclingTeamCubit>().loadDashboard(widget.teamId);
  }

  Future<void> _leaveTeam() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari tim?'),
        content: const Text(
          'Ringkasan sesi yang pernah dibagikan akan berhenti terlihat '
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
}

class _TeamAccessRequired extends StatelessWidget {
  const _TeamAccessRequired({required this.configured});

  final bool configured;

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
                : 'Fitur tim memerlukan konfigurasi akun online.',
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
  const _PrivacyNotice();

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
              'Data perjalanan hanya terlihat oleh tim jika anggota memilih '
              'membagikan ringkasannya. Lokasi live dan koordinat GPS tidak '
              'dibagikan.',
            ),
          ),
        ],
      ),
    ),
  );
}

class _TeamListCard extends StatelessWidget {
  const _TeamListCard({required this.team, required this.onTap});

  final CyclingTeam team;
  final VoidCallback onTap;

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
  const _InviteCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) => SenapathCard(
    child: ListTile(
      leading: const Icon(Icons.vpn_key_outlined),
      title: const Text('Kode undangan'),
      subtitle: SelectableText(
        code,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
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
  const _TeamSummaryCards({
    required this.dashboard,
    required this.metric,
  });

  final CyclingTeamDashboard dashboard;
  final bool metric;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _MetricCard(
        label: 'Sesi dibagikan',
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
                dashboard.totalDistanceMeters /
                    dashboard.totalDurationSeconds,
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
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

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
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${sessions.length} sesi'),
                    Text(_formatDistance(distance, metric)),
                    if (duration > 0)
                      Text('Aktif ${_durationLabel(duration)}'),
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

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Belum ada sesi selesai yang bisa dibagikan.'),
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
                            ? 'Bagikan ringkasan sesi ke tim'
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
  const _TeamFormResult({
    required this.name,
    required this.inviteCode,
    required this.displayName,
  });

  final String name;
  final String inviteCode;
  final String displayName;
}

String _durationLabel(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '$minutes mnt';
  return '$hours jam $minutes mnt';
}

String _formatDistance(double meters, bool metric) => metric
    ? '${(meters / 1000).toStringAsFixed(1)} km'
    : '${(meters / 1609.344).toStringAsFixed(1)} mi';

String _formatSpeed(double metersPerSecond, bool metric) {
  final speed = metersPerSecond * (metric ? 3.6 : 2.236936);
  return '${speed.toStringAsFixed(1)} ${metric ? 'km/jam' : 'mph'}';
}
