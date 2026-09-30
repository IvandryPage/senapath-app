import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/device_authenticator.dart';

class DeviceAuthState {
  const DeviceAuthState({
    this.isInitialized = false,
    this.isBusy = false,
    this.isUnlocked = false,
    this.hasBiometrics = false,
    this.supportsDeviceCredentials = false,
    this.message,
  });

  final bool isInitialized;
  final bool isBusy;
  final bool isUnlocked;
  final bool hasBiometrics;
  final bool supportsDeviceCredentials;
  final String? message;
}

class DeviceAuthCubit extends Cubit<DeviceAuthState> {
  DeviceAuthCubit(this._authenticator) : super(const DeviceAuthState());

  final DeviceAuthenticator _authenticator;

  Future<void> initialize() async {
    if (state.isInitialized || state.isBusy) return;

    try {
      final results = await Future.wait([
        _authenticator.hasEnrolledBiometrics,
        _authenticator.supportsDeviceCredentials,
      ]);
      emit(
        DeviceAuthState(
          isInitialized: true,
          hasBiometrics: results[0],
          supportsDeviceCredentials: results[1],
        ),
      );
    } catch (_) {
      emit(
        const DeviceAuthState(
          isInitialized: true,
          message: 'Autentikasi perangkat tidak dapat diperiksa.',
        ),
      );
    }
  }

  Future<void> authenticateWithBiometrics() async {
    if (!state.hasBiometrics) {
      _emitFailure('Biometrik belum tersedia atau belum terdaftar.');
      return;
    }
    await _authenticate(biometricOnly: true);
  }

  Future<void> authenticateWithDeviceCredentials() async {
    if (!state.supportsDeviceCredentials) {
      _emitFailure('Perangkat tidak menyediakan PIN atau sandi layar kunci.');
      return;
    }
    await _authenticate(biometricOnly: false);
  }

  Future<void> _authenticate({required bool biometricOnly}) async {
    emit(
      DeviceAuthState(
        isInitialized: true,
        isBusy: true,
        hasBiometrics: state.hasBiometrics,
        supportsDeviceCredentials: state.supportsDeviceCredentials,
      ),
    );

    try {
      final authenticated = await _authenticator.authenticate(
        biometricOnly: biometricOnly,
      );
      if (!authenticated) {
        _emitFailure('Autentikasi dibatalkan atau tidak berhasil.');
        return;
      }

      emit(
        DeviceAuthState(
          isInitialized: true,
          isUnlocked: true,
          hasBiometrics: state.hasBiometrics,
          supportsDeviceCredentials: state.supportsDeviceCredentials,
        ),
      );
    } catch (_) {
      _emitFailure(
        'Autentikasi gagal. Coba lagi atau gunakan sandi perangkat.',
      );
    }
  }

  void logout() {
    emit(
      DeviceAuthState(
        isInitialized: true,
        hasBiometrics: state.hasBiometrics,
        supportsDeviceCredentials: state.supportsDeviceCredentials,
      ),
    );
  }

  void _emitFailure(String message) {
    emit(
      DeviceAuthState(
        isInitialized: true,
        hasBiometrics: state.hasBiometrics,
        supportsDeviceCredentials: state.supportsDeviceCredentials,
        message: message,
      ),
    );
  }
}
