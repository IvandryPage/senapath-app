import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/data/custom_auth_session_manager.dart';
import '../domain/ai_chat_message.dart';
import 'ai_chat_gateway.dart';

class SupabaseAiChatGateway implements AiChatGateway {
  const SupabaseAiChatGateway(this._client, this._sessionManager);

  final SupabaseClient? _client;
  final CustomAuthSessionManager _sessionManager;

  @override
  bool get isConfigured => _client != null;

  @override
  Future<String> send({
    required List<AiChatMessage> messages,
    required Map<String, Object?> context,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase belum dikonfigurasi.');
    }

    if (_sessionManager.currentUserId == null) {
      throw StateError('Masuk ke akun online sebelum memakai chat AI.');
    }

    late final FunctionResponse response;
    try {
      response = await _sessionManager.invokeAuthenticatedFunction(
        'rider-assistant',
        body: {
          // Sending a chat message is the user's affirmative action.
          'consent': true,
          'messages': [
            for (final message in messages)
              {'role': message.role, 'content': message.content},
          ],
          'context': context,
        },
      );
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map ? details['error'] : null;
      if (message is String && message.trim().isNotEmpty) {
        throw StateError(message.trim());
      }
      if (error.status == 401 || error.status == 403) {
        throw StateError('Sesi akun tidak valid. Silakan masuk kembali.');
      }
      if (error.status == 429) {
        throw StateError('Batas penggunaan chat AI tercapai. Coba lagi nanti.');
      }
      if (error.status == 503) {
        throw StateError(
          'Layanan AI belum siap. Periksa konfigurasi Edge Function dan secrets Supabase.',
        );
      }
      throw StateError(
        'Edge Function rider-assistant gagal (HTTP ${error.status}). Periksa log Supabase Functions.',
      );
    }
    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final message = data is Map ? data['error'] : null;
      throw StateError(
        message is String && message.isNotEmpty
            ? message
            : 'Layanan AI gagal (HTTP ${response.status}).',
      );
    }
    final data = response.data;
    final reply = data is Map ? data['reply'] : null;
    if (reply is! String || reply.trim().isEmpty) {
      throw const FormatException('Respons AI tidak valid.');
    }
    return reply.trim();
  }
}
