import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/secure_vault.dart';
import 'package:senapath/features/gamification/domain/rider_progress.dart';
import 'package:senapath/features/profile/data/encrypted_avatar_store.dart';
import 'package:senapath/features/profile/data/user_profile_repository.dart';
import 'package:senapath/features/profile/domain/user_profile.dart';

class InMemorySecureVault implements SecureVault {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

SecureUserProfileRepository _repository(InMemorySecureVault vault) =>
    SecureUserProfileRepository(
      secureVault: vault,
      avatarStore: EncryptedAvatarStore(secureVault: vault),
    );

void main() {
  group('UserProfile', () {
    test('defaults to an unnamed explorer', () {
      const profile = UserProfile();
      expect(profile.displayName, '');
      expect(profile.riderStyle, RiderStyle.explorer);
    });

    test('round-trips through JSON', () {
      const profile = UserProfile(
        displayName: 'Budi',
        riderStyle: RiderStyle.climber,
      );
      final restored = UserProfile.fromJson(profile.toJson());
      expect(restored.displayName, 'Budi');
      expect(restored.riderStyle, RiderStyle.climber);
    });

    test('tolerates missing fields', () {
      final restored = UserProfile.fromJson(const {});
      expect(restored.displayName, '');
      expect(restored.riderStyle, RiderStyle.explorer);
    });
  });

  group('EmergencyContact', () {
    test('round-trips through JSON', () {
      const contact = EmergencyContact(
        id: 'c1',
        name: 'Ibu',
        phone: '+6281234567890',
        relationship: 'Ibu',
      );
      final restored = EmergencyContact.fromJson(contact.toJson());
      expect(restored.id, 'c1');
      expect(restored.name, 'Ibu');
      expect(restored.phone, '+6281234567890');
      expect(restored.relationship, 'Ibu');
    });
  });

  group('SecureUserProfileRepository (local)', () {
    test('returns a default profile when nothing is stored', () async {
      final repository = _repository(InMemorySecureVault());
      final profile = await repository.loadProfile();
      expect(profile.displayName, '');
      expect(profile.riderStyle, RiderStyle.explorer);
    });

    test('persists and reloads the profile', () async {
      final vault = InMemorySecureVault();
      final repository = _repository(vault);

      await repository.saveProfile(
        const UserProfile(
          displayName: 'Sari',
          riderStyle: RiderStyle.sprinter,
        ),
      );

      final fresh = _repository(vault);
      final profile = await fresh.loadProfile();
      expect(profile.displayName, 'Sari');
      expect(profile.riderStyle, RiderStyle.sprinter);
      expect(vault.values.containsKey('senapath.user_profile'), isTrue);
    });

    test('persists and reloads emergency contacts', () async {
      final vault = InMemorySecureVault();
      final repository = _repository(vault);

      expect(await repository.loadContacts(), isEmpty);

      await repository.saveContacts(const [
        EmergencyContact(
          id: 'c1',
          name: 'Ibu',
          phone: '+6281234567890',
          relationship: 'Ibu',
        ),
        EmergencyContact(
          id: 'c2',
          name: 'Ayah',
          phone: '+6289876543210',
          relationship: 'Ayah',
        ),
      ]);

      final contacts = await _repository(vault).loadContacts();
      expect(contacts, hasLength(2));
      expect(contacts.first.name, 'Ibu');
      expect(contacts.last.phone, '+6289876543210');
    });

    test('clears contacts by saving an empty list', () async {
      final vault = InMemorySecureVault();
      final repository = _repository(vault);
      await repository.saveContacts(const [
        EmergencyContact(
          id: 'c1',
          name: 'Ibu',
          phone: '+6281234567890',
          relationship: 'Ibu',
        ),
      ]);
      await repository.saveContacts(const []);
      expect(await repository.loadContacts(), isEmpty);
    });
  });

  group('SecureUserProfileRepository cloud gating', () {
    test('is not cloud-signed-in without a client or session', () {
      final repository = _repository(InMemorySecureVault());
      expect(repository.isCloudSignedIn, isFalse);
    });

    test('cloud loads return null when no session exists', () async {
      final repository = _repository(InMemorySecureVault());
      expect(await repository.loadCloudProfile(), isNull);
      expect(await repository.loadCloudContacts(), isNull);
    });

    test('cloud saves are no-ops without a session', () async {
      final repository = _repository(InMemorySecureVault());
      await repository.saveCloudProfile(
        const UserProfile(displayName: 'Budi'),
      );
      await repository.saveCloudContacts(const []);
      expect(repository.isCloudSignedIn, isFalse);
    });
  });
}
