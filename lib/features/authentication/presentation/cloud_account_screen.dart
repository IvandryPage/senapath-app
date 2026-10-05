import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cloud_account_cubit.dart';

class CloudAccountScreen extends StatefulWidget {
  const CloudAccountScreen({super.key});

  @override
  State<CloudAccountScreen> createState() => _CloudAccountScreenState();
}

class _CloudAccountScreenState extends State<CloudAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _isRegistering = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<CloudAccountCubit, CloudAccountState>(
    builder: (context, state) {
      if (state.isSignedIn) return _buildSignedIn(context, state);

      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          const Text(
            'Akun ini digunakan untuk layanan online. Unlock biometrik/PIN tetap terpisah dan melindungi data di perangkat.',
          ),
          const SizedBox(height: 16),
          if (!state.isConfigured)
            const _AccountNotice(
              text: 'Supabase belum dikonfigurasi. Fitur lokal tetap bisa digunakan.',
              isError: true,
            ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Masuk')),
              ButtonSegment(value: true, label: Text('Daftar')),
            ],
            selected: {_isRegistering},
            onSelectionChanged: state.isLoading || !state.isConfigured
                ? null
                : (selection) => setState(() {
                    _isRegistering = selection.first;
                    _confirmationController.clear();
                  }),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: state.isConfigured && !state.isLoading
                ? context.read<CloudAccountCubit>().signInWithGoogle
                : null,
            icon: state.isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.account_circle_outlined),
            label: Text(
              state.isLoading ? 'Memulai login Google…' : 'Lanjutkan dengan Google',
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('atau gunakan email'),
                ),
                Expanded(child: Divider()),
              ],
            ),
          ),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  enabled: state.isConfigured && !state.isLoading,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) =>
                      value == null ||
                          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(value.trim())
                      ? 'Masukkan email yang valid.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  enabled: state.isConfigured && !state.isLoading,
                  maxLength: 128,
                  obscureText: !_showPassword,
                  autofillHints: [
                    _isRegistering
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  textInputAction: _isRegistering
                      ? TextInputAction.next
                      : TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _showPassword
                          ? 'Sembunyikan password'
                          : 'Tampilkan password',
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => value == null || value.length < 8
                      ? 'Password minimal 8 karakter.'
                      : null,
                  onFieldSubmitted: _isRegistering ? null : (_) => _submit(),
                ),
                if (_isRegistering) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmationController,
                    enabled: state.isConfigured && !state.isLoading,
                    maxLength: 128,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Ulangi password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) => value != _passwordController.text
                        ? 'Password belum sama.'
                        : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
              ],
            ),
          ),
          if (!_isRegistering)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: state.isConfigured && !state.isLoading
                    ? _sendPasswordReset
                    : null,
                child: const Text('Lupa password?'),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: state.isConfigured && !state.isLoading ? _submit : null,
            child: state.isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isRegistering ? 'Buat akun' : 'Masuk'),
          ),
          if (state.status != null) ...[
            const SizedBox(height: 16),
            _AccountNotice(text: state.status!),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 16),
            _AccountNotice(text: state.error!, isError: true),
          ],
          if (_isRegistering) ...[
            const SizedBox(height: 16),
            Text(
              'Verifikasi email diperlukan sebelum masuk. Password dikirim melalui HTTPS ke layanan autentikasi Senapath dan disimpan di server hanya sebagai hash PBKDF2; aplikasi tidak menyimpan password.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      );
    },
  );

  Widget _buildSignedIn(BuildContext context, CloudAccountState state) =>
      ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          const Icon(Icons.verified_user_outlined, size: 40),
          const SizedBox(height: 12),
          Text('Akun online', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(state.email ?? ''),
          const SizedBox(height: 12),
          const Text(
            'Sesi cloud dipakai untuk layanan online. Data lokal tersimpan di perangkat dan tidak dihapus saat keluar dari akun.',
          ),
          if (state.status != null) ...[
            const SizedBox(height: 16),
            _AccountNotice(text: state.status!),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 16),
            _AccountNotice(text: state.error!, isError: true),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: state.isLoading
                ? null
                : context.read<CloudAccountCubit>().signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Keluar dari akun online'),
          ),
          if (state.isLoading) const LinearProgressIndicator(),
        ],
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<CloudAccountCubit>();
    if (_isRegistering) {
      await cubit.register(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } else {
      await cubit.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }
    if (!mounted || cubit.state.error != null) return;
    _passwordController.clear();
    _confirmationController.clear();
  }

  Future<void> _sendPasswordReset() async {
    if (!_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) return;
    }
    await context.read<CloudAccountCubit>().sendPasswordReset(
      _emailController.text,
    );
  }
}

class _AccountNotice extends StatelessWidget {
  const _AccountNotice({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isError
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text),
  );
}
