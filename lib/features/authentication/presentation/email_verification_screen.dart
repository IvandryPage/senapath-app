import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'cloud_account_cubit.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({required this.token, super.key});

  final String token;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CloudAccountCubit>().verifyEmail(widget.token);
    });
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<CloudAccountCubit, CloudAccountState>(
        builder: (context, state) {
          final verified =
              state.status?.startsWith('Email berhasil diverifikasi') == true;
          return Scaffold(
            appBar: AppBar(title: const Text('Verifikasi email')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.isLoading)
                      const CircularProgressIndicator()
                    else
                      Icon(
                        verified
                            ? Icons.verified_outlined
                            : Icons.error_outline,
                        size: 48,
                        color: verified
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      state.error ??
                          state.status ??
                          (widget.token.isEmpty
                              ? 'Token verifikasi tidak ditemukan.'
                              : 'Memverifikasi alamat email…'),
                      textAlign: TextAlign.center,
                    ),
                    if (verified) ...[
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => context.go('/account'),
                        child: const Text('Lanjut ke login'),
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
