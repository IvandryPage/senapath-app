import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ai_chat_message.dart';
import 'ai_chat_gateway.dart';

class SupabaseAiChatGateway implements AiChatGateway {
  const SupabaseAiChatGateway(this._client);

  final SupabaseClient? _client;

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

    if (client.auth.currentUser == null) {
      throw StateError('Masuk ke akun online sebelum memakai chat AI.');
    }

    final response = await client.functions.invoke(
      'rider-assistant',
      body: {
        'consent': true,
        'messages': [
          for (final message in messages)
            {'role': message.role, 'content': message.content},
        ],
        'context': context,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Layanan AI tidak tersedia.');
    }
    final data = response.data;
    final reply = data is Map ? data['reply'] : null;
    if (reply is! String || reply.trim().isEmpty) {
      throw const FormatException('Respons AI tidak valid.');
    }
    return reply.trim();
  }
}
