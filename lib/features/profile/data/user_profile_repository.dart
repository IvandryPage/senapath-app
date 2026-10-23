import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/storage/secure_vault.dart';
import '../../authentication/data/custom_auth_session_manager.dart';
import '../../gamification/domain/rider_progress.dart';
import '../domain/user_profile.dart';
import 'encrypted_avatar_store.dart';

abstract interface class UserProfileRepository {
  /// Memuat profil pengguna yang tersimpan.
  Future<UserProfile> loadProfile();
  /// Menyimpan profil pengguna.
  Future<void> saveProfile(UserProfile profile);
  /// Memuat daftar kontak darurat.
  Future<List<EmergencyContact>> loadContacts();
  /// Menyimpan daftar kontak darurat.
  Future<void> saveContacts(List<EmergencyContact> contacts);
  /// Memuat byte avatar pengguna bila ada.
  Future<Uint8List?> loadAvatar();
  /// Menyimpan byte avatar pengguna.
  Future<void> saveAvatar(Uint8List imageBytes);
}

abstract interface class CloudUserProfileRepository {
  /// Menandakan apakah pengguna sedang masuk ke akun cloud.
  bool get isCloudSignedIn;
  /// Memuat profil dari akun cloud, atau null bila belum tersedia.
  Future<UserProfile?> loadCloudProfile();
  /// Menyimpan profil ke akun cloud.
  Future<void> saveCloudProfile(UserProfile profile);
}

/// Optional capability for repositories that persist emergency contacts to the
/// account cloud, keeping them in sync across signed-in devices.
abstract interface class CloudContactsRepository {
  /// Memuat kontak darurat dari akun cloud, atau null bila tidak tersedia.
  Future<List<EmergencyContact>?> loadCloudContacts();
  /// Menyimpan kontak darurat ke akun cloud.
  Future<void> saveCloudContacts(List<EmergencyContact> contacts);
}

class CloudProfileSyncException implements Exception {
  /// Membungkus kesalahan sinkronisasi profil cloud beserta penyebabnya.
  const CloudProfileSyncException(this.cause);

  final Object cause;

  @override
  /// Menampilkan pesan kesalahan dari penyebab aslinya.
  String toString() => cause.toString();
}

class SecureUserProfileRepository
    implements
        UserProfileRepository,
        CloudUserProfileRepository,
        CloudContactsRepository {
  /// Membuat repositori profil yang memakai vault lokal dan sinkronisasi cloud.
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
  /// Mengecek ketersediaan klien cloud dan sesi pengguna yang aktif.
  bool get isCloudSignedIn =>
      cloudClient != null && sessionManager?.currentUserId != null;

  @override
  /// Memuat profil untuk pengguna aktif, memigrasikan data lama bila perlu.
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
  /// Menyimpan profil secara lokal dan menautkannya ke akun aktif.
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
  /// Mengambil profil dari tabel cloud pengguna yang sedang masuk.
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
  /// Menyimpan profil ke akun cloud melalui RPC dengan verifikasi sesi.
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
  /// Mengambil dan memvalidasi kontak darurat dari pengaturan akun cloud.
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
  /// Menyimpan kontak darurat ke pengaturan akun cloud.
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
  /// Membaca dan mengurai kontak darurat dari vault lokal.
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
  /// Menyimpan kontak darurat terenkode ke vault lokal.
  Future<void> saveContacts(List<EmergencyContact> contacts) =>
      secureVault.write(
        _contactsKey,
        jsonEncode(contacts.map((contact) => contact.toJson()).toList()),
      );

  @override
  /// Meneruskan pembacaan avatar ke penyimpanan terenkripsi.
  Future<Uint8List?> loadAvatar() => avatarStore.load();

  @override
  /// Meneruskan penyimpanan avatar ke penyimpanan terenkripsi.
  Future<void> saveAvatar(Uint8List imageBytes) => avatarStore.save(imageBytes);

  /// Menyusun kunci vault profil khusus untuk id pengguna.
  String _accountProfileKey(String userId) => '$_profileKey.$userId';
}
