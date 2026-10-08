import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../../session/data/session_file_service.dart';

class RouteFileExchange {
  const RouteFileExchange(this.fileService);

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
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: [
        XTypeGroup(label: extension.toUpperCase(), extensions: [extension]),
      ],
    );
    if (location == null) return false;
    await XFile.fromData(
      Uint8List.fromList(utf8.encode(content)),
      name: suggestedName,
      mimeType: mimeType,
    ).saveTo(location.path);
    return true;
  }
}
