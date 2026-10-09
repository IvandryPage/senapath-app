import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../routes/domain/saved_route.dart';
import '../../routes/presentation/routes_cubit.dart';
import 'ai_chat_cubit.dart';
import '../domain/ai_chat_message.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _messageController = TextEditingController();
  final _preferencesController = TextEditingController();
  final _scrollController = ScrollController();
  bool _consent = false;
  bool _includeRoute = false;
  bool _includePreferences = false;
  String? _selectedRouteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<RoutesCubit>().load());
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _preferencesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocListener<AiChatCubit, AiChatState>(
    listenWhen: (previous, current) =>
        previous.messages.length != current.messages.length ||
        previous.isSending != current.isSending,
    listener: (context, state) => _scrollToLatest(),
    child: BlocBuilder<AiChatCubit, AiChatState>(
      builder: (context, chatState) {
        final routes = context.watch<RoutesCubit>().state.routes;
        final selectedRoute = _findSelectedRoute(routes);
        final canSend =
            chatState.isConfigured &&
            _consent &&
            !chatState.isSending &&
            (!_includeRoute || selectedRoute != null) &&
            _messageController.text.trim().isNotEmpty;
        final colorScheme = Theme.of(context).colorScheme;

        return Column(
          children: [
            if (!chatState.isConfigured)
              const _ChatNotice(
                text: 'Chat belum terhubung. Pastikan Supabase project, rider-assistant function, dan GEMINI_API_KEY sudah dikonfigurasi.',
                isWarning: true,
              ),
            Expanded(
              child: chatState.messages.isEmpty
                  ? _WelcomeView(
                      isConfigured: chatState.isConfigured,
                      onPrompt: (prompt) {
                        _messageController
                          ..text = prompt
                          ..selection = TextSelection.collapsed(
                            offset: prompt.length,
                          );
                        setState(() {});
                      },
                    )
                  : ListView.builder(
                      key: const Key('ai-chat-messages'),
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                      itemCount:
                          chatState.messages.length +
                          (chatState.isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == chatState.messages.length) {
                          return const _TypingIndicator();
                        }
                        return _MessageBubble(
                          message: chatState.messages[index],
                        );
                      },
                    ),
            ),
            if (chatState.error != null)
              _ChatNotice(text: chatState.error!, isWarning: true),
            _Composer(
              controller: _messageController,
              consent: _consent,
              isConfigured: chatState.isConfigured,
              isSending: chatState.isSending,
              canSend: canSend,
              hasContext: _includeRoute || _includePreferences,
              onMessageChanged: (_) => setState(() {}),
              onConsentChanged: (value) =>
                  setState(() => _consent = value ?? false),
              onOpenContext: () => _showContextSheet(routes),
              onSend: () => unawaited(_send(context, selectedRoute)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'AI dapat keliru. Bukan pengganti panduan keselamatan atau saran medis.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        );
      },
    ),
  );

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showContextSheet(List<RouteRecord> routes) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Konteks untuk AI',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pilih hanya informasi yang ingin Anda bagikan ke Gemini.',
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _includeRoute,
                    onChanged: (value) =>
                        setSheetState(() => _includeRoute = value ?? false),
                    title: const Text('Sertakan rute'),
                  ),
                  if (_includeRoute)
                    routes.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Belum ada rute lokal untuk disertakan.',
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            initialValue:
                                routes.any(
                                  (route) => route.id == _selectedRouteId,
                                )
                                ? _selectedRouteId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Pilih rute',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final route in routes)
                                DropdownMenuItem(
                                  value: route.id,
                                  child: Text(route.name),
                                ),
                            ],
                            onChanged: (id) =>
                                setSheetState(() => _selectedRouteId = id),
                          ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _includePreferences,
                    onChanged: (value) => setSheetState(
                      () => _includePreferences = value ?? false,
                    ),
                    title: const Text('Sertakan preferensi latihan'),
                  ),
                  if (_includePreferences)
                    TextField(
                      controller: _preferencesController,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Preferensi latihan',
                        hintText: 'Contoh: jaga tenaga di tanjakan panjang',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Selesai'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  RouteRecord? _findSelectedRoute(List<RouteRecord> routes) {
    for (final route in routes) {
      if (route.id == _selectedRouteId) return route;
    }
    return null;
  }

  Future<void> _send(BuildContext context, RouteRecord? selectedRoute) async {
    final contextData = <String, Object?>{};
    if (_includeRoute && selectedRoute != null) {
      contextData['route'] = {
        'name': selectedRoute.name,
        'source': selectedRoute.source,
        'distanceMeters': selectedRoute.distanceMeters,
        'elevationGainMeters': selectedRoute.elevationGainMeters,
        'poiSummary': selectedRoute.poiSummary,
      };
    }
    final preferences = _preferencesController.text.trim();
    if (_includePreferences && preferences.isNotEmpty) {
      contextData['preferences'] = preferences;
    }

    final message = _messageController.text;
    final cubit = context.read<AiChatCubit>();
    await cubit.sendMessage(
      content: message,
      consent: _consent,
      context: contextData,
    );
    if (!mounted) return;
    if (cubit.state.error == null) _messageController.clear();
    setState(() {});
  }
}

class _WelcomeView extends StatelessWidget {
  const _WelcomeView({required this.isConfigured, required this.onPrompt});

  final bool isConfigured;
  final ValueChanged<String> onPrompt;

  static const _prompts = [
    'Bantu susun strategi untuk tanjakan panjang',
    'Apa yang perlu disiapkan sebelum ride jarak jauh?',
    'Bagaimana membagi tenaga saat latihan?',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: colors.primaryContainer,
              child: Icon(
                Icons.auto_awesome,
                color: colors.onPrimaryContainer,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Apa yang ingin kamu rencanakan?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              isConfigured
                  ? 'Tanya seputar latihan, persiapan, dan strategi bersepeda.'
                  : 'Chat akan aktif setelah backend Supabase dan Gemini siap.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            for (final prompt in _prompts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: isConfigured ? () => onPrompt(prompt) : null,
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    child: Text(prompt),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.84,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 17,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? colors.primaryContainer
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 5),
                      bottomRight: Radius.circular(isUser ? 5 : 20),
                    ),
                  ),
                  child: SelectableText(
                    message.content,
                    style: TextStyle(
                      color: isUser ? colors.onPrimaryContainer : null,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const SizedBox(
        width: 22,
        height: 18,
        child: Center(
          child: SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.consent,
    required this.isConfigured,
    required this.isSending,
    required this.canSend,
    required this.hasContext,
    required this.onMessageChanged,
    required this.onConsentChanged,
    required this.onOpenContext,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool consent;
  final bool isConfigured;
  final bool isSending;
  final bool canSend;
  final bool hasContext;
  final ValueChanged<String> onMessageChanged;
  final ValueChanged<bool?> onConsentChanged;
  final VoidCallback onOpenContext;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(26),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Pilih konteks',
                    onPressed: isConfigured && !isSending
                        ? onOpenContext
                        : null,
                    icon: Icon(
                      hasContext ? Icons.tune : Icons.add,
                      color: hasContext ? colors.primary : null,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      key: const Key('ai-chat-composer'),
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      enabled: isConfigured && !isSending,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onChanged: onMessageChanged,
                      onSubmitted: canSend ? (_) => onSend() : null,
                      decoration: const InputDecoration(
                        hintText: 'Tanya Senapath',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    key: const Key('ai-chat-send'),
                    tooltip: 'Kirim pesan',
                    onPressed: canSend ? onSend : null,
                    icon: isSending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Checkbox(
                value: consent,
                onChanged: isConfigured && !isSending ? onConsentChanged : null,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: isConfigured && !isSending
                      ? () => onConsentChanged(!consent)
                      : null,
                  child: Text(
                    'Setuju mengirim pesan${hasContext ? ' dan konteks pilihan' : ''} ke Gemini. Tidak disimpan sebagai riwayat.',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatNotice extends StatelessWidget {
  const _ChatNotice({required this.text, required this.isWarning});

  final String text;
  final bool isWarning;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: isWarning
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text),
  );
}
