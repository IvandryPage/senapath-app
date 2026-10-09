import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:phone_form_field/phone_form_field.dart';

import '../../../app/theme/senapath_design.dart';
import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../../emergency/presentation/emergency_cubit.dart';
import '../../authentication/presentation/cloud_account_cubit.dart';
import '../../progress/domain/activity_progress.dart';
import '../../progress/presentation/activity_goals_cubit.dart';
import '../domain/user_profile.dart';
import 'profile_cubit.dart';
import '../../session/domain/ride_session.dart';
import '../../session/presentation/session_cubit.dart';
import '../../teams/presentation/cycling_team_cubit.dart';

final _phoneFormCountries = allCountries
    .where((country) => country.isoCode != 'SJ')
    .toList(growable: false);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _imagePicker = ImagePicker();
  bool _startedLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedLoading) return;
    _startedLoading = true;
    unawaited(context.read<ProfileCubit>().load());
    unawaited(context.read<RideSessionCubit>().initialize());
    unawaited(context.read<ActivityGoalsCubit>().load());
    unawaited(context.read<CyclingTeamCubit>().loadTeams());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileCubit, ProfileState>(
      listenWhen: (previous, current) =>
          previous.message != current.message && current.message != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.message!)));
        context.read<ProfileCubit>().clearMessage();
      },
      child: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          if (!state.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          return BlocBuilder<RideSessionCubit, RideSessionState>(
            builder: (context, rideState) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _buildProfileSection(context, state),
                const SizedBox(height: 24),
                _ProfileProgressSection(
                  sessions: rideState.completedSessions,
                  isLoading: rideState.isLoading,
                  onSeeAll: () => context.push('/progress'),
                ),
                const SizedBox(height: 24),
                _RecentSessionsSection(
                  sessions: rideState.completedSessions,
                  isLoading: rideState.isLoading,
                  onSeeAll: () => context.push('/profile/sessions'),
                  onStartSession: () => context.go('/routes'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, ProfileState state) {
    final profile = state.profile;
    final colorScheme = Theme.of(context).colorScheme;
    final teamState = context.watch<CyclingTeamCubit>().state;
    final teamNames = teamState.teams.map((team) => team.name).join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: colorScheme.secondaryContainer,
              foregroundImage: state.avatarBytes == null
                  ? null
                  : MemoryImage(state.avatarBytes!),
              child: state.avatarBytes == null
                  ? Icon(Icons.person, size: 38, color: colorScheme.primary)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          profile.displayName.isEmpty
                              ? 'Nama belum diatur'
                              : profile.displayName,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit nama dan foto profil',
                        onPressed: () => _editProfile(profile, state.avatarBytes),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                    ],
                  ),
                  Text(
                    teamState.hasLoadedTeams
                        ? teamState.error != null
                              ? 'Nama tim tidak dapat dimuat'
                              : teamNames.isEmpty
                              ? 'Belum bergabung dengan tim'
                              : teamNames
                        : 'Memuat tim…',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  if (context.watch<CloudAccountCubit>().state.email
                      case final email?)
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Pengaturan dan menu profil',
              onPressed: _openProfileMenu,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openProfileMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            const ListTile(
              title: Text('Menu profil'),
              subtitle: Text('Pengaturan dan fitur lainnya'),
            ),
            _profileMenuItem(
              sheetContext,
              icon: Icons.health_and_safety_outlined,
              title: 'Kontak darurat',
              onTap: () {
                Navigator.pop(sheetContext);
                _openEmergencyContacts();
              },
            ),
            _profileMenuItem(
              sheetContext,
              icon: Icons.groups_outlined,
              title: 'Tim saya',
              onTap: () => _openMenuDestination(sheetContext, '/profile/teams'),
            ),
            _profileMenuItem(
              sheetContext,
              icon: Icons.route_outlined,
              title: 'Rute tersimpan',
              onTap: () =>
                  _openMenuDestination(sheetContext, '/profile/routes'),
            ),
            _profileMenuItem(
              sheetContext,
              icon: Icons.leaderboard_outlined,
              title: 'Papan peringkat',
              onTap: () => _openMenuDestination(sheetContext, '/leaderboard'),
            ),
            _profileMenuItem(
              sheetContext,
              icon: Icons.manage_accounts_outlined,
              title: 'Akun & keamanan',
              subtitle:
                  context.read<CloudAccountCubit>().state.email ??
                  'Kelola akun',
              onTap: () => _openMenuDestination(sheetContext, '/account'),
            ),
            _profileMenuItem(
              sheetContext,
              icon: Icons.tune,
              title: 'Pengaturan aplikasi',
              onTap: () =>
                  _openMenuDestination(sheetContext, '/profile/settings'),
            ),
            _profileMenuItem(
              sheetContext,
              icon: Icons.feedback_outlined,
              title: 'Saran dan kesan',
              onTap: () => _openMenuDestination(sheetContext, '/feedback'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileMenuItem(
    BuildContext sheetContext, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );

  void _openMenuDestination(BuildContext sheetContext, String route) {
    Navigator.pop(sheetContext);
    context.push(route);
  }

  Future<void> _openEmergencyContacts() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) => SafeArea(
        child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SingleChildScrollView(
            child: _buildContactsSection(context, state),
          ),
        ),
      ),
    ),
  );

  Widget _buildContactsSection(BuildContext context, ProfileState state) {
    final contacts = state.contacts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Kontak darurat',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text('${contacts.length}/${ProfileCubit.maximumContacts}'),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Tambah kontak darurat',
              onPressed: contacts.length >= ProfileCubit.maximumContacts
                  ? null
                  : () => _editContact(),
              icon: const Icon(Icons.person_add_alt_1),
            ),
          ],
        ),
        if (contacts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Belum ada kontak. Tambahkan orang yang dapat dihubungi.',
            ),
          )
        else
          for (final contact in contacts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(Icons.contact_phone_outlined),
              ),
              title: Text(contact.name),
              subtitle: Text('${contact.phone} · ${contact.relationship}'),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Telepon ${contact.name}',
                    onPressed: () => _callContact(contact),
                    icon: const Icon(Icons.call_outlined),
                  ),
                  IconButton(
                    tooltip: 'WhatsApp ${contact.name}',
                    onPressed: () => _openContactWhatsApp(contact),
                    icon: const Icon(Icons.chat_outlined),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Kelola ${contact.name}',
                    onSelected: (action) {
                      if (action == 'edit') _editContact(contact);
                      if (action == 'delete') _removeContact(contact);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Hapus'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Future<Uint8List?> _chooseAvatar() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (image == null || !mounted) return null;
      final bytes = await image.readAsBytes();
      if (!mounted) return null;
      return bytes;
    } catch (_) {
      if (!mounted) return null;
      _showMessage('Foto tidak dapat dibaca. Coba pilih gambar lain.');
      return null;
    }
  }

  Future<void> _editProfile(UserProfile profile, Uint8List? avatarBytes) async {
    final result = await showDialog<(UserProfile, Uint8List?)>(
      context: context,
      builder: (context) => _ProfileEditor(
        profile: profile,
        avatarBytes: avatarBytes,
        onChooseAvatar: _chooseAvatar,
      ),
    );
    if (result == null || !mounted) return;
    await context.read<ProfileCubit>().saveProfile(result.$1);
    if (result.$2 != null && mounted) {
      await context.read<ProfileCubit>().saveAvatar(result.$2!);
    }
  }

  Future<void> _editContact([EmergencyContact? contact]) async {
    final updated = await showDialog<EmergencyContact>(
      context: context,
      builder: (context) => _ContactEditor(contact: contact),
    );
    if (updated == null || !mounted) return;
    await context.read<ProfileCubit>().saveContact(updated);
  }

  Future<void> _removeContact(EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => SenapathAlertDialog(
        title: const Text('Hapus kontak?'),
        content: Text('${contact.name} akan dihapus dari kontak darurat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<ProfileCubit>().removeContact(contact.id);
    }
  }

  Future<void> _callContact(EmergencyContact contact) async {
    try {
      await context.read<EmergencyCubit>().callContact(contact);
      if (!mounted) return;
      final message = context.read<EmergencyCubit>().state.message;
      if (message != null) _showMessage(message);
      context.read<EmergencyCubit>().clearMessage();
    } catch (_) {
      if (mounted) _showMessage('Aplikasi telepon tidak dapat dibuka.');
    }
  }

  Future<void> _openContactWhatsApp(EmergencyContact contact) async {
    try {
      await context.read<EmergencyCubit>().openWhatsApp(contact);
      if (!mounted) return;
      final message = context.read<EmergencyCubit>().state.message;
      if (message != null) _showMessage(message);
      context.read<EmergencyCubit>().clearMessage();
    } catch (_) {
      if (mounted) _showMessage('WhatsApp tidak dapat dibuka.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileProgressSection extends StatelessWidget {
  const _ProfileProgressSection({
    required this.sessions,
    required this.isLoading,
    required this.onSeeAll,
  });

  static const _calculator = ActivityProgressCalculator();

  final List<RideSessionSnapshot> sessions;
  final bool isLoading;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final unit = context.watch<UnitSettingsCubit>().state.unitSystem;
    final week = _calculator.calculate(
      sessions,
      now: DateTime.now(),
      period: ProgressPeriod.week,
    );
    final goalsState = context.watch<ActivityGoalsCubit>().state;
    final weeklyGoals = goalsState.goals
        .where((goal) => goal.period == ProgressPeriod.week)
        .take(2)
        .toList(growable: false);
    final metric = unit == UnitSystem.metric;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileSectionTitle(
          title: 'Progres & target',
          actionLabel: 'Lihat semua',
          onAction: onSeeAll,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 6,
              child: _ProfileBentoTile(
                background: Theme.of(context).colorScheme.primaryContainer,
                foreground: Theme.of(context).colorScheme.onPrimaryContainer,
                icon: Icons.route_outlined,
                label: 'Jarak minggu ini',
                value: _profileDistance(week.distanceMeters, metric),
                helper: 'dari sesi selesai',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: _ProfileBentoTile(
                background: Theme.of(context).colorScheme.secondaryContainer,
                foreground: Theme.of(context).colorScheme.onSecondaryContainer,
                icon: Icons.directions_bike_outlined,
                label: 'Sesi',
                value: '${week.completedSessions}',
                helper: 'minggu ini',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (goalsState.isLoading && weeklyGoals.isEmpty)
          const LinearProgressIndicator()
        else if (weeklyGoals.isEmpty)
          SenapathCard(
            child: ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Belum ada target mingguan'),
              subtitle: const Text('Buat target pribadi di halaman progres.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onSeeAll,
            ),
          )
        else
          for (final goal in weeklyGoals)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ProfileGoalTile(
                goal: goal,
                progress: week,
                unitSystem: unit,
              ),
            ),
        if (isLoading && sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _ProfileBentoTile extends StatelessWidget {
  const _ProfileBentoTile({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
  final String label;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) => Container(
    height: 144,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: foreground),
        const Spacer(),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: foreground, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: foreground),
        ),
        Text(
          helper,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: foreground.withValues(alpha: 0.76)),
        ),
      ],
    ),
  );
}

class _ProfileGoalTile extends StatelessWidget {
  const _ProfileGoalTile({
    required this.goal,
    required this.progress,
    required this.unitSystem,
  });

  final ActivityGoal goal;
  final ActivityProgress progress;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final current = progress.valueFor(goal.metric);
    final progressValue = progress.progressFor(goal);
    final valueText = switch (goal.metric) {
      GoalMetric.completedSessions =>
        '${current.toStringAsFixed(0)} / ${goal.target.toStringAsFixed(0)} sesi',
      GoalMetric.distanceMeters =>
        '${_profileDistance(current, unitSystem == UnitSystem.metric)} / '
            '${_profileDistance(goal.target, unitSystem == UnitSystem.metric)}',
      GoalMetric.activeSeconds =>
        '${(current / 3600).toStringAsFixed(1)} / '
            '${(goal.target / 3600).toStringAsFixed(1)} jam',
    };
    final label = switch (goal.metric) {
      GoalMetric.completedSessions => 'Target sesi',
      GoalMetric.distanceMeters => 'Target jarak',
      GoalMetric.activeSeconds => 'Target durasi',
    };

    return SenapathCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label)),
                Text(
                  '${(progressValue * 100).round()}%',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progressValue),
            const SizedBox(height: 6),
            Text(valueText, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _RecentSessionsSection extends StatelessWidget {
  const _RecentSessionsSection({
    required this.sessions,
    required this.isLoading,
    required this.onSeeAll,
    required this.onStartSession,
  });

  final List<RideSessionSnapshot> sessions;
  final bool isLoading;
  final VoidCallback onSeeAll;
  final VoidCallback onStartSession;

  @override
  Widget build(BuildContext context) {
    final unit = context.watch<UnitSettingsCubit>().state.unitSystem;
    final recent = sessions.take(3).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileSectionTitle(
          title: 'Sesi terbaru',
          actionLabel: 'Lihat semua',
          onAction: onSeeAll,
        ),
        const SizedBox(height: 8),
        if (isLoading && sessions.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (recent.isEmpty)
          SenapathCard(
            child: ListTile(
              leading: const Icon(Icons.directions_bike_outlined),
              title: const Text('Belum ada sesi'),
              subtitle: const Text('Mulai perjalanan pertamamu dari Jelajah.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onStartSession,
            ),
          )
        else
          SenapathCard(
            child: Column(
              children: [
                for (var index = 0; index < recent.length; index++) ...[
                  if (index > 0) const Divider(height: 1, indent: 68),
                  _RecentSessionTile(session: recent[index], unitSystem: unit),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _RecentSessionTile extends StatelessWidget {
  const _RecentSessionTile({required this.session, required this.unitSystem});

  final RideSessionSnapshot session;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    final metric = unitSystem == UnitSystem.metric;
    final distance = _profileDistance(session.distanceMeters, metric);
    final duration = session
        .durationAt(session.endedAt ?? session.startedAt)
        .inMinutes;
    final date = DateFormat('d MMM yyyy').format(session.startedAt.toLocal());
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.directions_bike_outlined)),
      title: Text(
        session.title.isEmpty ? 'Perjalanan' : session.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('$date · $distance · ${duration}m'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/profile/sessions/${session.id}'),
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  const _ProfileSectionTitle({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      TextButton(onPressed: onAction, child: Text(actionLabel)),
    ],
  );
}

String _profileDistance(double meters, bool metric) => metric
    ? '${(meters / 1000).toStringAsFixed(1)} km'
    : '${(meters / 1609.344).toStringAsFixed(1)} mi';

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({
    required this.profile,
    required this.avatarBytes,
    required this.onChooseAvatar,
  });

  final UserProfile profile;
  final Uint8List? avatarBytes;
  final Future<Uint8List?> Function() onChooseAvatar;

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();
  late Uint8List? _avatarBytes;
  Uint8List? _updatedAvatarBytes;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _avatarBytes = widget.avatarBytes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _chooseAvatar() async {
    final bytes = await widget.onChooseAvatar();
    if (bytes != null && mounted) {
      setState(() {
        _avatarBytes = bytes;
        _updatedAvatarBytes = bytes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SenapathAlertDialog(
      title: const Text('Edit profil'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              foregroundImage: _avatarBytes == null
                  ? null
                  : MemoryImage(_avatarBytes!),
              child: _avatarBytes == null
                  ? const Icon(Icons.person, size: 36)
                  : null,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _chooseAvatar,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Ubah foto'),
            ),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Isi nama.' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              (
                UserProfile(
                  displayName: _nameController.text,
                  teamName: widget.profile.teamName,
                ),
                _updatedAvatarBytes,
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _ContactEditor extends StatefulWidget {
  const _ContactEditor({this.contact});

  final EmergencyContact? contact;

  @override
  State<_ContactEditor> createState() => _ContactEditorState();
}

class _ContactEditorState extends State<_ContactEditor> {
  late final TextEditingController _nameController;
  late final PhoneController _phoneController;
  late final TextEditingController _relationshipController;
  final _formKey = GlobalKey<FormState>();
  bool _phoneRequiredError = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact?.name ?? '');
    _phoneController = PhoneController(
      _parseStoredPhone(widget.contact?.phone),
    );
    _relationshipController = TextEditingController(
      text: widget.contact?.relationship ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SenapathAlertDialog(
      title: Text(widget.contact == null ? 'Tambah kontak' : 'Edit kontak'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Isi nama.' : null,
            ),
            const SizedBox(height: 16),
            PhoneFormField(
              controller: _phoneController,
              initialValue: _phoneController.value,
              defaultCountry: _defaultCountryCode,
              selectorNavigator: ModalBottomSheetNavigator(
                countries: _phoneFormCountries,
              ),
              errorText: 'Periksa format nomor telepon.',
              decoration: const InputDecoration(
                labelText: 'Nomor telepon atau WhatsApp',
                border: OutlineInputBorder(),
              ),
              onChanged: (phone) {
                if (_phoneRequiredError && phone?.nsn.isNotEmpty == true) {
                  setState(() => _phoneRequiredError = false);
                }
              },
            ),
            if (_phoneRequiredError)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12, top: 8),
                  child: Text(
                    'Isi nomor telepon.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _relationshipController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Hubungan',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Isi hubungan.'
                  : null,
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }

  String get _defaultCountryCode {
    final localeCountry = WidgetsBinding
        .instance
        .platformDispatcher
        .locale
        .countryCode
        ?.toUpperCase();
    if (localeCountry != null &&
        allCountries.any((country) => country.isoCode == localeCountry)) {
      return localeCountry;
    }
    return 'ID';
  }

  PhoneNumber? _parseStoredPhone(String? phone) {
    final value = phone?.trim();
    if (value == null || value.isEmpty) return null;
    final parser = PhoneParser();
    try {
      return value.startsWith('+')
          ? parser.parseRaw(value)
          : parser.parseWithIsoCode(_defaultCountryCode, value);
    } on Exception {
      return null;
    }
  }

  void _save() {
    final isFormValid = _formKey.currentState!.validate();
    final phone = _phoneController.value;
    final hasPhone = phone != null && phone.nsn.isNotEmpty;
    setState(() => _phoneRequiredError = !hasPhone);
    if (!isFormValid || !hasPhone) return;
    Navigator.pop(
      context,
      EmergencyContact(
        id: widget.contact?.id ?? _newContactId(),
        name: _nameController.text.trim(),
        phone: phone.international,
        relationship: _relationshipController.text.trim(),
      ),
    );
  }

  String _newContactId() {
    final random = Random.secure();
    final value = List<int>.generate(16, (_) => random.nextInt(256));
    value[6] = (value[6] & 0x0f) | 0x40;
    value[8] = (value[8] & 0x3f) | 0x80;
    final hex = value.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final compact = hex.join();
    return '${compact.substring(0, 8)}-${compact.substring(8, 12)}-'
        '${compact.substring(12, 16)}-${compact.substring(16, 20)}-'
        '${compact.substring(20)}';
  }
}
