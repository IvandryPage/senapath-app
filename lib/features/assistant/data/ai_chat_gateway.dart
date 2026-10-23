import '../domain/ai_chat_message.dart';

abstract interface class AiChatGateway {
  /// Menandakan layanan asisten AI sudah dikonfigurasi pada aplikasi.
  bool get isConfigured;

  /// Mengirim daftar pesan beserta konteks ke asisten dan mengembalikan balasannya.
  Future<String> send({
    required List<AiChatMessage> messages,
    required Map<String, Object?> context,
  });
}
