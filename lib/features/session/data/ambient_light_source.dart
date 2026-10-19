import 'dart:io';

import 'package:flutter/services.dart';

abstract interface class AmbientLightSource {
  Stream<int> get readings;
}

class DeviceAmbientLightSource implements AmbientLightSource {
  const DeviceAmbientLightSource();

  static const _channel = EventChannel('senapath/ambient_light');

  @override
  Stream<int> get readings {
    if (!Platform.isAndroid) return const Stream<int>.empty();
    return _channel.receiveBroadcastStream().map((event) {
      if (event is! num || !event.isFinite || event < 0) {
        throw const FormatException('Invalid ambient light sensor reading.');
      }
      return event.round();
    });
  }
}

bool shouldUseLightTheme({required bool isBright, required int lux}) {
  if (lux < 0) return isBright;
  return isBright ? lux >= 150 : lux >= 300;
}
