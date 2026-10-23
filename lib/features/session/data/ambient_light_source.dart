import 'dart:io';

import 'package:flutter/services.dart';

/// Sumber cahaya ambien perangkat.
abstract interface class AmbientLightSource {
  /// Aliran pembacaan cahaya dalam lux.
  Stream<int> get readings;
}

/// Sumber cahaya ambien berbasis EventChannel.
class DeviceAmbientLightSource implements AmbientLightSource {
  /// Membuat sumber cahaya ambien.
  const DeviceAmbientLightSource();

  static const _channel = EventChannel('senapath/ambient_light');

  @override
  /// Mengambil pembacaan cahaya ambien jika tersedia.
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

/// Menentukan penggunaan tema terang berdasarkan cahaya ambien.
bool shouldUseLightTheme({required bool isBright, required int lux}) {
  if (lux < 0) return isBright;
  return isBright ? lux >= 150 : lux >= 300;
}
