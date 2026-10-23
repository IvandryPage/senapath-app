import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureVault {
  /// Membaca nilai rahasia untuk [key], atau null bila belum tersimpan.
  Future<String?> read(String key);
  /// Menyimpan [value] sebagai nilai rahasia untuk [key].
  Future<void> write(String key, String value);
  /// Menghapus nilai rahasia yang tersimpan pada [key].
  Future<void> delete(String key);
}

class FlutterSecureVault implements SecureVault {
  /// Membuat vault berbasis flutter_secure_storage dengan penyimpanan opsional.
  FlutterSecureVault({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Meneruskan pembacaan nilai rahasia ke penyimpanan aman platform.
  @override
  Future<String?> read(String key) => _storage.read(key: key);

  /// Meneruskan penyimpanan nilai rahasia ke penyimpanan aman platform.
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  /// Meneruskan penghapusan nilai rahasia ke penyimpanan aman platform.
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
