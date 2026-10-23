import 'dart:io';

import 'package:path_provider/path_provider.dart';

class OfflineStorageUsage {
  /// Membuat ringkasan pemakaian penyimpanan basis data dan cache peta.
  const OfflineStorageUsage({
    required this.databaseBytes,
    required this.mapCacheBytes,
  });

  final int databaseBytes;
  final int mapCacheBytes;
}

class OfflineStorageManager {
  /// Membuat pengelola penyimpanan offline tanpa state.
  const OfflineStorageManager();

  /// Menghitung ukuran berkas basis data dan direktori cache peta saat ini.
  Future<OfflineStorageUsage> usage() async {
    final documents = await getApplicationDocumentsDirectory();
    final support = await getApplicationSupportDirectory();
    return OfflineStorageUsage(
      databaseBytes: await _sizeOf(
        File('${documents.path}${Platform.pathSeparator}senapath.sqlite'),
      ),
      mapCacheBytes: await _sizeOf(
        Directory('${support.path}${Platform.pathSeparator}map_cache'),
      ),
    );
  }

  /// Menghapus seluruh isi direktori cache peta jika direktori tersebut ada.
  Future<void> clearMapCache() async {
    final support = await getApplicationSupportDirectory();
    final cache = Directory(
      '${support.path}${Platform.pathSeparator}map_cache',
    );
    if (await cache.exists()) await cache.delete(recursive: true);
  }

  /// Menjumlahkan ukuran berkas atau seluruh isi direktori secara rekursif.
  Future<int> _sizeOf(FileSystemEntity entity) async {
    if (!await entity.exists()) return 0;
    if (entity is File) return entity.length();
    if (entity is Directory) {
      var total = 0;
      await for (final child in entity.list(recursive: true)) {
        if (child is File) total += await child.length();
      }
      return total;
    }
    return 0;
  }
}
