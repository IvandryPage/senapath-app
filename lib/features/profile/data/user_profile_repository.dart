import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/storage/secure_vault.dart';
import '../../authentication/data/custom_auth_session_manager.dart';
import '../../gamification/domain/rider_progress.dart';
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

abstract interface class CloudUserProfileRepository {
  bool get isCloudSignedIn;
  Future<UserProfile?> loadCloudProfile();
  Future<void> saveCloudProfile(UserProfile profile);
}

/// Optional capability for repositories that persist emergency contacts to the
/// account cloud, keeping them in sync across signed-in devices.
abstract interface class CloudContactsRepository {
  Future<List<EmergencyContact>?> loadCloudContacts();
  Future<void> saveCloudContacts(List<EmergencyContact> contacts);
}

class CloudProfileSyncException implements Exception {
  const CloudProfileSyncException(this.cause);

  final Object cause;

  @override
  String toString() => cause.toString();
}

class SecureUserProfileRepository
    implements
        UserProfileRepository,
        CloudUserProfileRepository,
        CloudContactsRepository {
  SecureUserProfileRepository({
    required this.secureVault,
    required this.avatarStore,
    this.cloudClient,
    this.sessionManager,
  });

  static const _profileKey = 'senapath.user_profile';
  static const _profileAccountKey = 'senapath.user_profile.account_id';
  static const _contactsKey = 'senapath.emergency_contacts';
  static const _contactsCloudKey = 'emergency_contacts_v1';

  final SecureVault secureVault;
  final EncryptedAvatarStore avatarStore;
  final SupabaseClient? cloudClient;
  final CustomAuthSessionManager? sessionManager;

  @override
  bool get isCloudSignedIn =>
      cloudClient != null && sessionManager?.currentUserId != null;

  @override
  Future<UserProfile> loadProfile() async {
    final userId = sessionManager?.currentUserId;
    if (userId != null) {
      final accountValue = await secureVault.read(_accountProfileKey(userId));
      if (accountValue != null) {
        return UserProfile.fromJson(
          jsonDecode(accountValue) as Map<String, dynamic>,
        );
      }

      final linkedUserId = await secureVault.read(_profileAccountKey);
      if (linkedUserId != null && linkedUserId != userId) {
        return const UserProfile();
      }
      final legacyValue = await secureVault.read(_profileKey);
      if (legacyValue != null) {
        await secureVault.write(_accountProfileKey(userId), legacyValue);
        await secureVault.write(_profileAccountKey, userId);
        return UserProfile.fromJson(
          jsonDecode(legacyValue) as Map<String, dynamic>,
        );
      }
      return const UserProfile();
    }

    final value = await secureVault.read(_profileKey);
    if (value == null) return const UserProfile();
    return UserProfile.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    final encoded = jsonEncode(profile.toJson());
    await secureVault.write(_profileKey, encoded);
    final userId = sessionManager?.currentUserId;
    if (userId != null) {
      await secureVault.write(_accountProfileKey(userId), encoded);
      await secureVault.write(_profileAccountKey, userId);
    }
  }

  @override
  Future<UserProfile?> loadCloudProfile() async {
    final manager = sessionManager;
    final client = cloudClient;
    final userId = manager?.currentUserId;
    if (manager == null || client == null || userId == null) return null;
    try {
      await manager.requireAccessToken();
      if (manager.currentUserId != userId) {
        throw StateError('Akun berubah saat profil dimuat.');
      }
      final row = await client
          .from('rider_profiles')
          .select('display_name, rider_style')
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      return UserProfile(
        displayName: row['display_name'] as String? ?? '',
        riderStyle: RiderStyle.fromName(row['rider_style']),
      );
    } catch (error) {
      throw CloudProfileSyncException(error);
    }
  }

  @override
  Future<void> saveCloudProfile(UserProfile profile) async {
    final manager = sessionManager;
    final client = cloudClient;
    final userId = manager?.currentUserId;
    if (manager == null || client == null || userId == null) return;
    try {
      await manager.requireAccessToken();
      if (manager.currentUserId != userId) {
        throw StateError('Akun berubah saat profil disimpan.');
      }
      await client.rpc(
        'set_my_account_profile',
        params: {
          'p_display_name': profile.displayName,
          'p_rider_style': profile.riderStyle.name,
        },
      );
    } catch (error) {
      throw CloudProfileSyncException(error);
    }
  }

  @override
  Future<List<EmergencyContact>?> loadCloudContacts() async {
    final manager = sessionManager;
    final client = cloudClient;
    final userId = manager?.currentUserId;
    if (manager == null || client == null || userId == null) return null;
    try {
      await manager.requireAccessToken();
      final row = await client
          .from('account_settings')
          .select('value')
          .eq('user_id', userId)
          .eq('key', _contactsCloudKey)
          .maybeSingle();
      final value = row?['value'];
      if (value == null) return null;
      if (value is! List) {
        throw const FormatException('Kontak darurat cloud tidak valid.');
      }
      return [
        for (final entry in value)
          if (entry is Map)
            EmergencyContact.fromJson(Map<String, dynamic>.from(entry)),
      ];
    } catch (error) {
      throw CloudProfileSyncException(error);
    }
  }

  @override
  Future<void> saveCloudContacts(List<EmergencyContact> contacts) async {
    final manager = sessionManager;
    final client = cloudClient;
    final userId = manager?.currentUserId;
    if (manager == null || client == null || userId == null) return;
    try {
      await manager.requireAccessToken();
      await client.from('account_settings').upsert({
        'user_id': userId,
        'key': _contactsCloudKey,
        'value': contacts.map((contact) => contact.toJson()).toList(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,key');
    } catch (error) {
      throw CloudProfileSyncException(error);
    }
  }

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

  String _accountProfileKey(String userId) => '$_profileKey.$userId';
}
