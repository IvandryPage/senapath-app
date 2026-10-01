import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<FeedbackCubit>().load());
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<FeedbackCubit, FeedbackState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              'Bagikan saran atau kesan untuk tim Senapath.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Pengiriman memerlukan jaringan. Jika gagal, pesan disimpan terenkripsi di perangkat agar bisa dicoba lagi. Pesan terkirim disimpan server untuk ditinjau. Jangan sertakan data pribadi atau kontak darurat.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              minLines: 4,
              maxLines: 8,
              maxLength: 4000,
              decoration: const InputDecoration(
                labelText: 'Saran dan kesan',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _consent,
              onChanged: state.isSubmitting
                  ? null
                  : (value) => setState(() => _consent = value ?? false),
              title: const Text(
                'Saya setuju feedback ini dikirim ke tim Senapath melalui Supabase.',
              ),
              subtitle: const Text(
                'Jika belum terkirim, simpan secara terenkripsi di perangkat untuk retry.',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed:
                    state.isSubmitting ||
                        !_consent ||
                        _messageController.text.trim().isEmpty
                    ? null
                    : () => unawaited(_submit(context)),
                icon: state.isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: const Text('Kirim feedback'),
              ),
            ),
            if (state.status != null) ...[
              const SizedBox(height: 12),
              Text(state.status!),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (state.pending.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Belum terkirim',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final submission in state.pending)
                Card(
                  child: ListTile(
                    title: Text(
                      DateFormat('d MMM yyyy · HH:mm')
                          .format(submission.createdAt.toLocal()),
                    ),
                    subtitle: Text(submission.message),
                    trailing: IconButton(
                      tooltip: 'Coba kirim lagi',
                      onPressed: state.isSubmitting
                          ? null
                          : () => unawaited(
                              context.read<FeedbackCubit>().retry(
                                submission.id,
                              ),
                            ),
                      icon: const Icon(Icons.sync),
                    ),
                  ),
                ),
            ],
          ],
        ),
      );

  Future<void> _submit(BuildContext context) async {
    final accepted = await context.read<FeedbackCubit>().submit(
      _messageController.text,
      consent: _consent,
    );
    if (!mounted || !accepted) return;
    setState(() {
      _messageController.clear();
      _consent = false;
    });
  }
}
