import 'package:local_auth/local_auth.dart';

abstract interface class DeviceAuthenticator {
  /// Menentukan apakah perangkat memiliki biometrik terdaftar.
  Future<bool> get hasEnrolledBiometrics;

  /// Menentukan apakah perangkat mendukung kredensial perangkat.
  Future<bool> get supportsDeviceCredentials;

  /// Meminta autentikasi perangkat dan mengembalikan hasilnya.
  Future<bool> authenticate({required bool biometricOnly});
}

class LocalDeviceAuthenticator implements DeviceAuthenticator {
  /// Membuat autentikator perangkat lokal.
  LocalDeviceAuthenticator({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  /// Memeriksa ketersediaan biometrik yang terdaftar.
  @override
  Future<bool> get hasEnrolledBiometrics async {
    final canCheck = await _authentication.canCheckBiometrics;
    final biometrics = await _authentication.getAvailableBiometrics();
    return canCheck && biometrics.isNotEmpty;
  }

  /// Menentukan dukungan kredensial perangkat.
  @override
  Future<bool> get supportsDeviceCredentials =>
      _authentication.isDeviceSupported();

  /// Menjalankan dialog autentikasi biometrik atau perangkat.
  @override
  Future<bool> authenticate({required bool biometricOnly}) =>
      _authentication.authenticate(
        localizedReason:
            'Masuk ke akun Senapath yang tersimpan di perangkat ini.',
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: false,
      );
}
