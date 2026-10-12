import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/routes/data/route_file_exchange.dart';
import 'package:senapath/features/session/data/session_file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('senapath/file_export');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'Android export saves content through the native document picker',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      Map<Object?, Object?>? receivedArguments;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'saveFile');
        receivedArguments = call.arguments as Map<Object?, Object?>;
        return true;
      });

      final exported = await const RouteFileExchange(SessionFileService())
          .exportText(
            content: '<gpx />',
            suggestedName: 'ride.gpx',
            extension: 'gpx',
            mimeType: 'application/gpx+xml',
          );

      expect(exported, isTrue);
      expect(receivedArguments?['fileName'], 'ride.gpx');
      expect(receivedArguments?['mimeType'], 'application/gpx+xml');
      expect(
        receivedArguments?['bytes'],
        Uint8List.fromList(utf8.encode('<gpx />')),
      );
    },
  );

  test(
    'Android export returns false when the user cancels the picker',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      messenger.setMockMethodCallHandler(channel, (_) async => false);

      final exported = await const RouteFileExchange(SessionFileService())
          .exportText(
            content: '<gpx />',
            suggestedName: 'ride.gpx',
            extension: 'gpx',
            mimeType: 'application/gpx+xml',
          );

      expect(exported, isFalse);
    },
  );
}
