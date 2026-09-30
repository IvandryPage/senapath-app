import 'dart:convert';
import 'dart:typed_data';

import '../../../core/storage/secure_vault.dart';
import '../domain/user_profile.dart';
import 'encrypted_avatar_store.dart';

abstract interface class UserProfileRepository {
  Future<UserProfile> loadProfile();
  Future<void> saveProfile(UserProfile profile);
  Future<List<EmergencyContact>> loadContacts();
  Future<void> saveContacts(List<EmergencyContact> contacts);
  Future<Uint8List?> loadAvatar();
  Future<void> saveAvatar(Uint8List imageBytes);
}

class SecureUserProfileRepository implements UserProfileRepository {
  SecureUserProfileRepository({
    required this.secureVault,
    required this.avatarStore,
  });

  static const _profileKey = 'senapath.user_profile';
  static const _contactsKey = 'senapath.emergency_contacts';

  final SecureVault secureVault;
  final EncryptedAvatarStore avatarStore;

  @override
  Future<UserProfile> loadProfile() async {
    final value = await secureVault.read(_profileKey);
    if (value == null) return const UserProfile();
    return UserProfile.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  @override
  Future<void> saveProfile(UserProfile profile) =>
      secureVault.write(_profileKey, jsonEncode(profile.toJson()));

  @override
  Future<List<EmergencyContact>> loadContacts() async {
    final value = await secureVault.read(_contactsKey);
    if (value == null) return const [];
    final entries = jsonDecode(value) as List<dynamic>;
    return entries
        .map(
          (entry) => EmergencyContact.fromJson(entry as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveContacts(List<EmergencyContact> contacts) =>
      secureVault.write(
        _contactsKey,
        jsonEncode(contacts.map((contact) => contact.toJson()).toList()),
      );

  @override
  Future<Uint8List?> loadAvatar() => avatarStore.load();

  @override
  Future<void> saveAvatar(Uint8List imageBytes) => avatarStore.save(imageBytes);
}
