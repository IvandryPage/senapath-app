import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../../core/storage/secure_vault.dart';
import '../domain/ride_session.dart';

class EncryptedTelemetryCodec {
  EncryptedTelemetryCodec({required this.secureVault, AesGcm? cipher})
    : _cipher = cipher ?? AesGcm.with256bits();

  static const _keyName = 'senapath.telemetry.encryption_key';

  final SecureVault secureVault;
  final AesGcm _cipher;

  Future<Uint8List> encode(TelemetryLocation location) async {
    final cleartext = utf8.encode(jsonEncode(location.toJson()));
    return encryptBytes(cleartext);
  }

  Future<Uint8List> encryptBytes(List<int> cleartext) async {
    final key = await _loadOrCreateKey();
    if (key == null) {
      throw StateError('Telemetry encryption key is unavailable.');
    }
    final secretBox = await _cipher.encrypt(
      cleartext,
      secretKey: SecretKey(key),
    );
    return secretBox.concatenation();
  }

  Future<TelemetryLocation> decode(
    Uint8List encrypted, {
    required DateTime recordedAt,
  }) async {
    final cleartext = await decryptBytes(encrypted);
    return TelemetryLocation.fromJson(
      jsonDecode(utf8.decode(cleartext)) as Map<String, dynamic>,
      recordedAt: recordedAt,
    );
  }

  Future<Uint8List> decryptBytes(Uint8List encrypted) async {
    final key = await _loadOrCreateKey(create: false);
    if (key == null) throw StateError('Telemetry encryption key is missing.');

    final secretBox = SecretBox.fromConcatenation(
      encrypted,
      nonceLength: 12,
      macLength: 16,
    );
    final cleartext = await _cipher.decrypt(
      secretBox,
      secretKey: SecretKey(key),
    );
    return Uint8List.fromList(cleartext);
  }

  Future<List<int>?> _loadOrCreateKey({bool create = true}) async {
    final stored = await secureVault.read(_keyName);
    if (stored != null) return base64Decode(stored);
    if (!create) return null;

    final secretKey = await _cipher.newSecretKey();
    final bytes = await secretKey.extractBytes();
    await secureVault.write(_keyName, base64Encode(bytes));
    return bytes;
  }
}
