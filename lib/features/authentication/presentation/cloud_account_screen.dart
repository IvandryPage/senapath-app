import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/senapath_design.dart';
import '../../../core/validation/input_formatters.dart';
import '../../../core/validation/validators.dart';
import 'cloud_account_cubit.dart';

/// Layar akun cloud dan autentikasi.
class CloudAccountScreen extends StatefulWidget {
  /// Membuat layar akun cloud.
  const CloudAccountScreen({this.isEntryFlow = false, super.key});

  /// Menandai apakah layar ini bagian alur masuk awal.
  final bool isEntryFlow;

  /// Membuat state untuk layar akun cloud.
  @override
  State<CloudAccountScreen> createState() => _CloudAccountScreenState();
}

/// State untuk layar akun cloud.
class _CloudAccountScreenState extends State<CloudAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _isRegistering = false;
  bool _showPassword = false;

  /// Membersihkan controller saat widget dibuang.
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  /// Membangun tampilan akun cloud berdasarkan status autentikasi.
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<CloudAccountCubit, CloudAccountState>(
    builder: (context, state) {
      if (state.isSignedIn) return _buildSignedIn(context, state);

      final loginPage = ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          if (widget.isEntryFlow) ...[
            const SizedBox(height: 36),
            const SizedBox(height: 18),
            Text(
              'Perjalananmu.\nRuangmu.',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: SenapathColors.white,
                fontWeight: FontWeight.w900,
                height: 1.02,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Masuk untuk menyimpan perjalanan dan memakai fitur akun Senapath.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: SenapathColors.white.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(height: 24),
          ] else
            const Text(
              'Masuk dengan email dan kata sandi. Kamu juga bisa memakai sidik jari atau wajah untuk masuk kembali di perangkat ini.',
            ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              boxShadow: [
                BoxShadow(
                  color: SenapathColors.ink.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!state.isConfigured)
                  const _AccountNotice(
                    text: 'Akun online belum tersedia. Fitur di ponsel tetap bisa digunakan.',
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
                if (!_isRegistering &&
                    state.biometricSignInEnabled &&
                    state.canUseBiometrics)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: state.isLoading
                          ? null
                          : context
                                .read<CloudAccountCubit>()
                                .signInWithBiometrics,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Masuk dengan sidik jari atau wajah'),
                    ),
                  ),
                const SizedBox(height: 20),
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
                        inputFormatters: [
                          const SingleLineInputFormatter(),
                          const ForbiddenCharactersInputFormatter(),
                          LengthLimitingTextInputFormatter(
                            InputLimits.emailMaxLength,
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: TextValidators.email,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        enabled: state.isConfigured && !state.isLoading,
                        maxLength: InputLimits.passwordMaxLength,
                        obscureText: !_showPassword,
                        autofillHints: [
                          _isRegistering
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        textInputAction: _isRegistering
                            ? TextInputAction.next
                            : TextInputAction.done,
                        inputFormatters: const [
                          SingleLineInputFormatter(),
                          ForbiddenCharactersInputFormatter(),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Kata sandi',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _showPassword
                                ? 'Sembunyikan kata sandi'
                                : 'Tampilkan kata sandi',
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: TextValidators.password,
                        onFieldSubmitted: _isRegistering
                            ? null
                            : (_) => _submit(),
                      ),
                      if (_isRegistering) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmationController,
                          enabled: state.isConfigured && !state.isLoading,
                          maxLength: InputLimits.passwordMaxLength,
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          inputFormatters: const [
                            SingleLineInputFormatter(),
                            ForbiddenCharactersInputFormatter(),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Ulangi kata sandi',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) =>
                              TextValidators.passwordConfirmation(
                                value,
                                _passwordController.text,
                              ),
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SenapathButton(
                  onPressed: state.isConfigured && !state.isLoading
                      ? _submit
                      : null,
                  icon: _isRegistering ? Icons.person_add_alt_1 : Icons.login,
                  isLoading: state.isLoading,
                  label: _isRegistering ? 'Daftar' : 'Masuk',
                ),
                if (state.status != null) ...[
                  const SizedBox(height: 16),
                  _AccountNotice(text: state.status!),
                ],
                if (state.error != null) ...[
                  const SizedBox(height: 16),
                  _AccountNotice(text: state.error!, isError: true),
                ],
              ],
            ),
          ),
        ],
      );
      if (!widget.isEntryFlow) return loginPage;

      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/app_home_cta.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            semanticLabel: 'Pesepeda menyusuri jalan di antara perbukitan',
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66071122),
                  Color(0x99071122),
                  Color(0xD9071122),
                ],
              ),
            ),
          ),
          SafeArea(child: loginPage),
        ],
      );
    },
  );

  /// Membangun tampilan saat pengguna telah masuk.
  Widget _buildSignedIn(BuildContext context, CloudAccountState state) =>
      ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          const Icon(Icons.verified_user_outlined, size: 40),
          const SizedBox(height: 12),
          Text(
            'Akun & keamanan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(state.email ?? ''),
          const SizedBox(height: 12),
          const Text(
            'Akun online dipakai untuk fitur yang memerlukan internet. Perjalanan di ponsel tetap tersimpan saat kamu keluar dari akun.',
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
            label: const Text('Keluar dari akun'),
          ),
          if (state.isLoading) const LinearProgressIndicator(),
        ],
      );

  /// Mengirim formulir masuk atau pendaftaran.
  Future<void> _submit() async {
    if (context.read<CloudAccountCubit>().state.isLoading) return;
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
}

/// Notifikasi status atau error akun.
class _AccountNotice extends StatelessWidget {
  /// Membuat notifikasi akun.
  const _AccountNotice({required this.text, this.isError = false});

  final String text;
  final bool isError;

  /// Membangun tampilan notifikasi akun.
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
