import '../domain/ai_chat_message.dart';

abstract interface class AiChatGateway {
  bool get isConfigured;

  Future<String> send({
    required List<AiChatMessage> messages,
    required Map<String, Object?> context,
  });
}
