import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../../session/data/session_file_service.dart';
import '../../session/domain/ride_session.dart';

class RouteFileExchange {
  const RouteFileExchange(this.fileService);

  final SessionFileService fileService;

  Future<List<TelemetryLocation>?> importGpx() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'GPX route', extensions: ['gpx']),
      ],
    );
    if (file == null) return null;
    return fileService.parseGpx(await file.readAsString());
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
      Uint8List.fromList(content.codeUnits),
      name: suggestedName,
      mimeType: mimeType,
    ).saveTo(location.path);
    return true;
  }
}
