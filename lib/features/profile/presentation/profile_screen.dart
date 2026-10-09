import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phone_form_field/phone_form_field.dart';

import '../../../app/theme/senapath_design.dart';
import '../../emergency/presentation/emergency_cubit.dart';
import '../../authentication/presentation/cloud_account_cubit.dart';
import '../domain/user_profile.dart';
import 'profile_cubit.dart';

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

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _buildProfileSection(context, state),
              const SizedBox(height: 8),
              _buildSectionHeading(
                context,
                icon: Icons.health_and_safety_outlined,
                title: 'Keselamatan',
                subtitle: 'Orang yang dapat dihubungi saat dibutuhkan.',
              ),
              const SizedBox(height: 8),
              SenapathCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildContactsSection(context, state),
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionHeading(
                context,
                icon: Icons.groups_2_outlined,
                title: 'Tim',
                subtitle: 'Anggota dan ringkasan perjalanan bersama.',
              ),
              const SizedBox(height: 8),
              SenapathCard(
                child: ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('Tim saya'),
                  subtitle: const Text('Buat tim atau gabung dengan kode undangan'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/teams'),
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionHeading(
                context,
                icon: Icons.directions_bike_outlined,
                title: 'Aktivitas',
                subtitle: 'Perjalanan, progres, dan rute tersimpan.',
              ),
              const SizedBox(height: 8),
              _buildActivityNavigation(context),
              const SizedBox(height: 20),
              _buildSectionHeading(
                context,
                icon: Icons.tune,
                title: 'Akun dan aplikasi',
                subtitle: 'Pengaturan, akun, dan keamanan.',
              ),
              const SizedBox(height: 8),
              _buildAccountNavigation(context),
              const SizedBox(height: 20),
              _buildSectionHeading(
                context,
                icon: Icons.info_outline,
                title: 'Tentang',
                subtitle: 'Informasi untuk mata kuliah aplikasi mobile.',
              ),
              const SizedBox(height: 8),
              _buildAboutNavigation(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCloudAccountEntry(BuildContext context) {
    final account = context.watch<CloudAccountCubit>().state;
    return ListTile(
      leading: Icon(
        account.isSignedIn
            ? Icons.verified_user_outlined
            : Icons.manage_accounts_outlined,
      ),
      title: const Text('Akun & keamanan'),
      subtitle: Text(account.email ?? 'Kelola akun dan keamanan'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/account'),
    );
  }

  Widget _buildSectionHeading(
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
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );

  Widget _buildActivityNavigation(BuildContext context) => SenapathCard(
    child: Column(
      children: [
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Riwayat sesi'),
          subtitle: const Text('Aktivitas dan ringkasan perjalanan'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/profile/sessions'),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.insights_outlined),
          title: const Text('Progres dan target'),
          subtitle: const Text('Statistik aktivitas mingguan dan bulanan'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/progress'),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.route_outlined),
          title: const Text('Rute tersimpan'),
          subtitle: const Text('Kelola GPX untuk perjalanan berikutnya'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/profile/routes'),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.leaderboard_outlined),
          title: const Text('Papan peringkat'),
          subtitle: const Text('Peringkat mingguan · opsional'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/leaderboard'),
        ),
      ],
    ),
  );

  Widget _buildAccountNavigation(BuildContext context) => SenapathCard(
    child: Column(
      children: [
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Pengaturan'),
          subtitle: const Text('Satuan, tema, dan penyimpanan'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/profile/settings'),
        ),
        const Divider(height: 1),
        _buildCloudAccountEntry(context),
      ],
    ),
  );

  Widget _buildAboutNavigation(BuildContext context) => SenapathCard(
    child: Column(
      children: [
        ListTile(
          leading: const Icon(Icons.feedback_outlined),
          title: const Text('Saran dan kesan'),
          subtitle: const Text('Mata Kuliah Pemrograman Aplikasi Mobile'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/feedback'),
        ),
      ],
    ),
  );

  Widget _buildProfileSection(BuildContext context, ProfileState state) {
    final profile = state.profile;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: colorScheme.secondaryContainer,
              foregroundImage: state.avatarBytes == null
                  ? null
                  : MemoryImage(state.avatarBytes!),
              child: state.avatarBytes == null
                  ? Icon(Icons.person, size: 34, color: colorScheme.primary)
                  : null,
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              tooltip: 'Pilih foto profil',
              onPressed: _chooseAvatar,
              icon: const Icon(Icons.photo_camera_outlined),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName.isEmpty
                        ? 'Nama belum diatur'
                        : profile.displayName,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (profile.teamName.isNotEmpty)
                    Text(
                      profile.teamName,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit profil',
              onPressed: () => _editProfile(profile),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Divider(),
      ],
    );
  }

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

  Future<void> _chooseAvatar() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      await context.read<ProfileCubit>().saveAvatar(bytes);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Foto tidak dapat dibaca. Coba pilih gambar lain.');
    }
  }

  Future<void> _editProfile(UserProfile profile) async {
    final updated = await showDialog<UserProfile>(
      context: context,
      builder: (context) => _ProfileEditor(profile: profile),
    );
    if (updated == null || !mounted) return;
    await context.read<ProfileCubit>().saveProfile(updated);
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
      builder: (context) => AlertDialog(
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

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.profile});

  final UserProfile profile;

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _teamController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _teamController = TextEditingController(text: widget.profile.teamName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profil'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Isi nama.' : null,
            ),
            TextFormField(
              controller: _teamController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Tim (opsional)'),
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
              UserProfile(
                displayName: _nameController.text,
                teamName: _teamController.text,
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
    return AlertDialog(
      title: Text(widget.contact == null ? 'Tambah kontak' : 'Edit kontak'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Isi nama.' : null,
            ),
            PhoneFormField(
              controller: _phoneController,
              defaultCountry: _defaultCountryCode,
              selectorNavigator: ModalBottomSheetNavigator(
                countries: _phoneFormCountries,
              ),
              errorText: 'Periksa format nomor telepon.',
              decoration: const InputDecoration(
                labelText: 'Nomor telepon atau WhatsApp',
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
            TextFormField(
              controller: _relationshipController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Hubungan'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Isi hubungan.'
                  : null,
            ),
          ],
        ),
      ),
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
