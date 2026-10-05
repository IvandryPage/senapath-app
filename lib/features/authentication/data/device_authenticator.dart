import 'package:local_auth/local_auth.dart';

abstract interface class DeviceAuthenticator {
  Future<bool> get hasEnrolledBiometrics;
  Future<bool> get supportsDeviceCredentials;
  Future<bool> authenticate({required bool biometricOnly});
}

class LocalDeviceAuthenticator implements DeviceAuthenticator {
  LocalDeviceAuthenticator({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> get hasEnrolledBiometrics async {
    final canCheck = await _authentication.canCheckBiometrics;
    final biometrics = await _authentication.getAvailableBiometrics();
    return canCheck && biometrics.isNotEmpty;
  }

  @override
  Future<bool> get supportsDeviceCredentials =>
      _authentication.isDeviceSupported();

  @override
  Future<bool> authenticate({required bool biometricOnly}) =>
      _authentication.authenticate(
        localizedReason: 'Masuk ke akun Senapath yang tersimpan di perangkat ini.',
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: false,
      );
}
