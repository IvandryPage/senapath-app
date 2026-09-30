import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'device_auth_cubit.dart';

class DeviceUnlockScreen extends StatelessWidget {
  const DeviceUnlockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeviceAuthCubit, DeviceAuthState>(
      builder: (context, state) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.directions_bike,
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Buka Senapath',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gunakan keamanan perangkat untuk membuka data latihan.',
                    textAlign: TextAlign.center,
                  ),
                  if (state.isBusy || !state.isInitialized) ...[
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(),
                  ] else ...[
                    const SizedBox(height: 24),
                    if (state.hasBiometrics)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => context
                              .read<DeviceAuthCubit>()
                              .authenticateWithBiometrics(),
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Masuk dengan biometrik'),
                        ),
                      ),
                    if (state.supportsDeviceCredentials) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => context
                              .read<DeviceAuthCubit>()
                              .authenticateWithDeviceCredentials(),
                          icon: const Icon(Icons.password),
                          label: const Text('Gunakan PIN atau sandi perangkat'),
                        ),
                      ),
                    ],
                    if (!state.hasBiometrics &&
                        !state.supportsDeviceCredentials)
                      const Text(
                        'Perangkat belum menyiapkan biometrik atau kunci layar. '
                        'Atur keamanan perangkat untuk melanjutkan.',
                        textAlign: TextAlign.center,
                      ),
                  ],
                  if (state.message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      state.message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
