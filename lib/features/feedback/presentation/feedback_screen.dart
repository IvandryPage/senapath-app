import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/senapath_design.dart';
import 'feedback_cubit.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _messageController = TextEditingController();
  bool _consent = false;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<FeedbackCubit>().load());
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeedbackCubit, FeedbackState>(
      builder: (context, state) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text(
            'Masukan untuk Senapath',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Masukan dipakai untuk memperbaiki aplikasi. Jika dikirim, '
            'masukan terhubung ke akun online dan disimpan di server; jangka '
            'waktu penyimpanan server belum ditentukan. Jangan sertakan '
            'password, token, atau data pribadi sensitif. Jika belum berhasil '
            'dikirim, masukan disimpan di penyimpanan aman perangkat dan dapat '
            'dicoba kembali.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SenapathCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _messageController,
                    minLines: 5,
                    maxLines: 10,
                    maxLength: 4000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Masukan',
                      hintText: 'Ceritakan saran atau kendala yang kamu alami',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _consent,
                    onChanged: state.isSubmitting
                        ? null
                        : (value) => setState(() => _consent = value ?? false),
                    title: const Text(
                      'Saya setuju mengirim masukan ini untuk perbaikan aplikasi.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (state.error case final error?) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  if (state.status case final status?) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        status,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: state.isSubmitting
                        ? null
                        : () async {
                            final saved = await context
                                .read<FeedbackCubit>()
                                .submit(
                                  _messageController.text,
                                  consent: _consent,
                                );
                            if (saved && mounted) {
                              _messageController.clear();
                              setState(() => _consent = false);
                            }
                          },
                    icon: state.isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: const Text('Kirim masukan'),
                  ),
                ],
              ),
            ),
          ),
          if (state.isLoading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (state.pending.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Belum terkirim (${state.pending.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final submission in state.pending)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SenapathCard(
                  child: ListTile(
                    title: Text(submission.message),
                    subtitle: Text(
                      'Disimpan ${submission.createdAt.toLocal().toString().split('.').first}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Coba kirim ulang',
                      onPressed: state.isSubmitting
                          ? null
                          : () => context.read<FeedbackCubit>().retry(
                              submission.id,
                            ),
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
