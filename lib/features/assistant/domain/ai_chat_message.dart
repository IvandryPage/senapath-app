class AiChatMessage {
  /// Membuat pesan chat dengan peran pengguna atau asisten beserta isinya.
  const AiChatMessage({required this.role, required this.content});

  final String role;
  final String content;
}
