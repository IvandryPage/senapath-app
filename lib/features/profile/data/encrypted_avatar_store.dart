import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/secure_vault.dart';

class EncryptedAvatarStore {
  /// Membuat penyimpanan avatar dengan vault aman dan cipher AES-GCM opsional.
  EncryptedAvatarStore({required this.secureVault, AesGcm? cipher})
    : _cipher = cipher ?? AesGcm.with256bits();

  static const _encryptionKey = 'senapath.profile.avatar_key';
  static const _fileName = 'profile_avatar.enc';

  final SecureVault secureVault;
  final AesGcm _cipher;

  /// Mengenkripsi lalu menulis byte gambar avatar ke berkas penyimpanan.
  Future<void> save(Uint8List imageBytes) async {
    final key = await _loadOrCreateKey();
    if (key == null) throw StateError('Avatar encryption key is unavailable.');
    final secretBox = await _cipher.encrypt(
      imageBytes,
      secretKey: SecretKey(key),
    );
    final file = await _avatarFile();
    await file.writeAsBytes(secretBox.concatenation(), flush: true);
  }

  /// Membaca dan mendekripsi avatar tersimpan, atau null bila belum ada.
  Future<Uint8List?> load() async {
    final file = await _avatarFile();
    if (!await file.exists()) return null;

    final encoded = await file.readAsBytes();
    final key = await _loadOrCreateKey(create: false);
    if (key == null) return null;

    final secretBox = SecretBox.fromConcatenation(
      encoded,
      nonceLength: 12,
      macLength: 16,
    );
    final cleartext = await _cipher.decrypt(
      secretBox,
      secretKey: SecretKey(key),
    );
    return Uint8List.fromList(cleartext);
  }

  /// Menghapus berkas avatar beserta kunci enkripsinya dari penyimpanan.
  Future<void> delete() async {
    final file = await _avatarFile();
    if (await file.exists()) await file.delete();
    await secureVault.delete(_encryptionKey);
  }

  /// Mengambil kunci dari vault, membuat kunci baru bila diminta dan belum ada.
  Future<List<int>?> _loadOrCreateKey({bool create = true}) async {
    final storedKey = await secureVault.read(_encryptionKey);
    if (storedKey != null) return base64Decode(storedKey);
    if (!create) return null;

    final key = await _cipher.newSecretKey();
    final bytes = await key.extractBytes();
    await secureVault.write(_encryptionKey, base64Encode(bytes));
    return bytes;
  }

  /// Menyiapkan direktori dukungan aplikasi dan mengembalikan berkas avatar.
  Future<File> _avatarFile() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }
}
