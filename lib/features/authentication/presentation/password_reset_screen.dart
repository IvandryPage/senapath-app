import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'cloud_account_cubit.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({required this.token, super.key});

  final String token;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<CloudAccountCubit, CloudAccountState>(
    listener: (context, state) {
      if (state.status?.startsWith('Password berhasil diperbarui') == true) {
        context.go('/account');
      }
    },
    builder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Atur ulang password')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Buat password baru untuk akun Senapath. Tautan reset hanya dapat digunakan sekali.',
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _passwordController,
                  maxLength: 128,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(
                    labelText: 'Password baru',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.length < 8
                      ? 'Password minimal 8 karakter.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmationController,
                  maxLength: 128,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Ulangi password baru',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value != _passwordController.text
                      ? 'Password belum sama.'
                      : null,
                ),
              ],
            ),
          ),
          if (widget.token.isEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Token reset tidak ditemukan. Minta tautan reset yang baru.',
            ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: state.isLoading || widget.token.isEmpty ? null : _submit,
            child: state.isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Simpan password baru'),
          ),
        ],
      ),
    ),
  );

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<CloudAccountCubit>().completePasswordReset(
      token: widget.token,
      password: _passwordController.text,
    );
  }
}
