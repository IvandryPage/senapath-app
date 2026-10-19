import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../session/data/session_file_service.dart';

class RouteFileExchange {
  const RouteFileExchange(this.fileService);

  static const _androidFileExportChannel = MethodChannel(
    'senapath/file_export',
  );

  final SessionFileService fileService;

  Future<GpxImport?> importGpx() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'GPX route', extensions: ['gpx']),
      ],
    );
    if (file == null) return null;
    final size = await file.length();
    if (size > SessionFileService.maximumGpxBytes) {
      throw const FormatException('Ukuran GPX melebihi batas 10 MB.');
    }
    return fileService.parseGpxDocument(await file.readAsString());
  }

  Future<bool> exportText({
    required String content,
    required String suggestedName,
    required String extension,
    required String mimeType,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return await _androidFileExportChannel.invokeMethod<bool>('saveFile', {
            'bytes': bytes,
            'fileName': suggestedName,
            'mimeType': mimeType,
          }) ??
          false;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final result = await SharePlus.instance.share(
        ShareParams(
          title: suggestedName,
          files: [
            XFile.fromData(bytes, name: suggestedName, mimeType: mimeType),
          ],
        ),
      );
      return result.status != ShareResultStatus.dismissed;
    }

    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: [
        XTypeGroup(label: extension.toUpperCase(), extensions: [extension]),
      ],
    );
    if (location == null) return false;
    await XFile.fromData(
      bytes,
      name: suggestedName,
      mimeType: mimeType,
    ).saveTo(location.path);
    return true;
  }
}
