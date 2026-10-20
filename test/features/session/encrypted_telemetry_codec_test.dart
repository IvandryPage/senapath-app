import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/secure_vault.dart';
import 'package:senapath/features/session/data/encrypted_telemetry_codec.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

class InMemorySecureVault implements SecureVault {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

TelemetryLocation _location(DateTime recordedAt) => TelemetryLocation(
  recordedAt: recordedAt,
  latitude: -6.2,
  longitude: 106.8,
  accuracyMeters: 5,
  altitudeMeters: 20,
  speedMetersPerSecond: 7.5,
);

void main() {
  group('EncryptedTelemetryCodec', () {
    test('encrypts and decrypts a telemetry location', () async {
      final vault = InMemorySecureVault();
      final codec = EncryptedTelemetryCodec(secureVault: vault);
      final recordedAt = DateTime.utc(2026, 1, 5, 10);

      final encrypted = await codec.encode(_location(recordedAt));
      expect(encrypted, isNotEmpty);
      expect(
        utf8.decode(encrypted, allowMalformed: true),
        isNot(contains('106.8')),
        reason: 'payload must not leak cleartext coordinates',
      );

      final decoded = await codec.decode(encrypted, recordedAt: recordedAt);
      expect(decoded.latitude, -6.2);
      expect(decoded.longitude, 106.8);
      expect(decoded.accuracyMeters, 5);
      expect(decoded.altitudeMeters, 20);
      expect(decoded.speedMetersPerSecond, 7.5);
      expect(decoded.recordedAt, recordedAt);
    });

    test('produces a fresh ciphertext for the same location', () async {
      final vault = InMemorySecureVault();
      final codec = EncryptedTelemetryCodec(secureVault: vault);
      final recordedAt = DateTime.utc(2026, 1, 5, 10);

      final first = await codec.encode(_location(recordedAt));
      final second = await codec.encode(_location(recordedAt));
      expect(first, isNot(equals(second)));
    });

    test('reuses the key stored in the vault', () async {
      final vault = InMemorySecureVault();
      final codec = EncryptedTelemetryCodec(secureVault: vault);
      final recordedAt = DateTime.utc(2026, 1, 5, 10);

      final encrypted = await codec.encode(_location(recordedAt));
      expect(
        await vault.read('senapath.telemetry.encryption_key'),
        isNotNull,
      );

      final reader = EncryptedTelemetryCodec(secureVault: vault);
      final decoded = await reader.decode(encrypted, recordedAt: recordedAt);
      expect(decoded.latitude, -6.2);
    });

    test('fails to decrypt without a stored key', () async {
      final codec = EncryptedTelemetryCodec(secureVault: InMemorySecureVault());
      await expectLater(
        codec.decryptBytes(Uint8List.fromList(List.filled(64, 1))),
        throwsA(isA<StateError>()),
      );
    });

    test('fails to decrypt a tampered payload', () async {
      final vault = InMemorySecureVault();
      final codec = EncryptedTelemetryCodec(secureVault: vault, cipher: AesGcm.with256bits());
      final encrypted = await codec.encryptBytes(utf8.encode('payload'));
      encrypted[encrypted.length - 1] ^= 0xFF;

      await expectLater(
        codec.decryptBytes(encrypted),
        throwsA(anything),
      );
    });
  });
}
