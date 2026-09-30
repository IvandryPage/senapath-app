import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/units/unit_settings_cubit.dart';
import '../../../core/units/unit_system.dart';
import '../domain/user_profile.dart';
import 'profile_cubit.dart';

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
    unawaited(context.read<UnitSettingsCubit>().load());
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
              const SizedBox(height: 28),
              _buildContactsSection(context, state),
              const SizedBox(height: 28),
              _buildUnitSection(context),
              const SizedBox(height: 20),
              const Text(
                'Profil dan kontak disimpan aman di perangkat. '
                'Sinkronisasi cloud menunggu konfigurasi Supabase.',
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }

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
                    tooltip: 'Edit ${contact.name}',
                    onPressed: () => _editContact(contact),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Hapus ${contact.name}',
                    onPressed: () => _removeContact(contact),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
        const Divider(),
      ],
    );
  }

  Widget _buildUnitSection(BuildContext context) {
    return BlocBuilder<UnitSettingsCubit, UnitSettingsState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sistem satuan',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
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
        );
      },
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

  Future<void> _saveUnitSystem(UnitSystem unitSystem) async {
    try {
      await context.read<UnitSettingsCubit>().select(unitSystem);
    } catch (_) {
      if (mounted) _showMessage('Satuan tidak dapat disimpan.');
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
  late final TextEditingController _phoneController;
  late final TextEditingController _relationshipController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact?.name ?? '');
    _phoneController = TextEditingController(text: widget.contact?.phone ?? '');
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
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor telepon atau WhatsApp',
              ),
              validator: _validatePhone,
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

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Isi nomor telepon.';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final validCharacters = RegExp(r'^\+?[0-9 ()-]+$').hasMatch(value.trim());
    if (!validCharacters || digits.length < 7 || digits.length > 15) {
      return 'Periksa format nomor telepon.';
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      EmergencyContact(
        id: widget.contact?.id ?? _newContactId(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
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
