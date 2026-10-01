import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../routes/domain/saved_route.dart';
import '../../routes/presentation/routes_cubit.dart';
import 'ai_chat_cubit.dart';

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
        previous.messages.length != current.messages.length,
    listener: (context, state) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    },
    child: BlocBuilder<AiChatCubit, AiChatState>(
      builder: (context, chatState) {
        final routesState = context.watch<RoutesCubit>().state;
        final selectedRoute = _findSelectedRoute(routesState.routes);
        final canSend =
            chatState.isConfigured &&
            _consent &&
            !chatState.isSending &&
            (!_includeRoute || selectedRoute != null) &&
            _messageController.text.trim().isNotEmpty;

        return Column(
          children: [
            if (!chatState.isConfigured)
              const _ChatNotice(
                text: 'AI belum tersambung. Proyek perlu konfigurasi Supabase dan Edge Function Gemini.',
                isWarning: true,
              ),
            Expanded(
              child: chatState.messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          chatState.isConfigured
                              ? 'Tanyakan strategi latihan atau rute. Jawaban AI bukan diagnosis atau jaminan keselamatan.'
                              : 'Chat akan aktif setelah backend dikonfigurasi. Tidak ada pesan yang dikirim.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: chatState.messages.length,
                      itemBuilder: (context, index) {
                        final message = chatState.messages[index];
                        final isUser = message.role == 'user';
                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 340),
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                  : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(message.content),
                          ),
                        );
                      },
                    ),
            ),
            if (chatState.isSending) const LinearProgressIndicator(),
            if (chatState.error != null)
              _ChatNotice(text: chatState.error!, isWarning: true),
            _buildContextControls(context, routesState.routes),
            CheckboxListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              value: _consent,
              onChanged: chatState.isConfigured
                  ? (value) => setState(() => _consent = value ?? false)
                  : null,
              title: const Text(
                'Saya setuju mengirim pesan dan konteks pilihan ke Gemini melalui Supabase.',
              ),
              subtitle: const Text(
                'Jangan masukkan kontak darurat atau informasi sensitif. Chat tidak disimpan sebagai riwayat lokal.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      enabled: chatState.isConfigured && !chatState.isSending,
                      decoration: const InputDecoration(
                        hintText: 'Tulis pesan',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: canSend
                          ? (_) => _send(context, selectedRoute)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Kirim pesan',
                    onPressed: canSend
                        ? () => _send(context, selectedRoute)
                        : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _buildContextControls(
    BuildContext context,
    List<RouteRecord> routes,
  ) => ExpansionTile(
    title: const Text('Konteks yang disertakan'),
    subtitle: const Text('Pilih data yang boleh dikirim ke AI'),
    children: [
      CheckboxListTile(
        dense: true,
        value: _includeRoute,
        onChanged: (value) => setState(() => _includeRoute = value ?? false),
        title: const Text('Sertakan rute'),
      ),
      if (_includeRoute)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: routes.isEmpty
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Belum ada rute lokal untuk disertakan.'),
                  ),
                )
              : DropdownButtonFormField<String>(
                  initialValue:
                      routes.any((route) => route.id == _selectedRouteId)
                      ? _selectedRouteId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Rute yang dibagikan',
                  ),
                  items: [
                    for (final route in routes)
                      DropdownMenuItem(
                        value: route.id,
                        child: Text(route.name),
                      ),
                  ],
                  onChanged: (id) => setState(() => _selectedRouteId = id),
                ),
        ),
      CheckboxListTile(
        dense: true,
        value: _includePreferences,
        onChanged: (value) =>
            setState(() => _includePreferences = value ?? false),
        title: const Text('Sertakan preferensi latihan'),
      ),
      if (_includePreferences)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _preferencesController,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Preferensi yang ingin dipakai',
              hintText: 'Contoh: jaga tenaga di tanjakan panjang',
              border: OutlineInputBorder(),
            ),
          ),
        ),
    ],
  );

  RouteRecord? _findSelectedRoute(List<RouteRecord> routes) {
    for (final route in routes) {
      if (route.id == _selectedRouteId) return route;
    }
    return null;
  }

  void _send(BuildContext context, RouteRecord? selectedRoute) {
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
    _messageController.clear();
    setState(() {});
    unawaited(
      context.read<AiChatCubit>().sendMessage(
        content: message,
        consent: _consent,
        context: contextData,
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
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    color: isWarning
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Text(text),
  );
}
