import 'package:flutter_bloc/flutter_bloc.dart';

import 'dart:async';

import '../../../core/validation/validators.dart';
import '../data/ai_chat_gateway.dart';
import '../domain/ai_chat_message.dart';

class AiChatState {
  /// Membuat state chat AI dengan daftar pesan dan status awal opsional.
  const AiChatState({
    this.messages = const [],
    this.isSending = false,
    this.isConfigured = false,
    this.error,
  });

  final List<AiChatMessage> messages;
  final bool isSending;
  final bool isConfigured;
  final String? error;

  /// Menyalin state dengan pesan, status pengiriman, atau error baru.
  AiChatState copyWith({
    List<AiChatMessage>? messages,
    bool? isSending,
    bool? isConfigured,
    String? error,
    bool clearError = false,
  }) => AiChatState(
    messages: messages ?? this.messages,
    isSending: isSending ?? this.isSending,
    isConfigured: isConfigured ?? this.isConfigured,
    error: clearError ? null : error ?? this.error,
  );
}

class AiChatCubit extends Cubit<AiChatState> {
  /// Membuat cubit chat AI dengan gateway sebagai sumber respon.
  AiChatCubit(this._gateway)
    : super(AiChatState(isConfigured: _gateway.isConfigured));

  final AiChatGateway _gateway;
  int _requestGeneration = 0;

  bool get isConfigured => _gateway.isConfigured;

  /// Menghapus seluruh percakapan dan mereset status pengiriman.
  void clearConversation() {
    if (isClosed) return;
    _requestGeneration++;
    emit(
      state.copyWith(messages: const [], isSending: false, clearError: true),
    );
  }

  /// Mengirim pesan ke asisten, menambahkan balasan, dan menangani error.
  Future<void> sendMessage({
    required String content,
    Map<String, Object?> context = const {},
  }) async {
    final message = TextValidators.stripForbiddenCharacters(
      content,
      allowLineBreaks: true,
    ).trim();
    if (state.isSending || message.isEmpty) return;
    if (message.length > InputLimits.chatMessageMaxLength) {
      emit(
        state.copyWith(
          error: 'Pesan maksimal ${InputLimits.chatMessageMaxLength} karakter.',
        ),
      );
      return;
    }
    if (!isConfigured) {
      emit(
        state.copyWith(error: 'Asisten belum dikonfigurasi. Coba lagi nanti.'),
      );
      return;
    }

    final conversation = [
      ...state.messages,
      AiChatMessage(role: 'user', content: message),
    ];
    final requestGeneration = ++_requestGeneration;
    emit(
      state.copyWith(
        messages: List.unmodifiable(conversation),
        isSending: true,
        clearError: true,
      ),
    );

    try {
      final reply = await _gateway.send(
        messages: conversation.length <= 20
            ? conversation
            : conversation.sublist(conversation.length - 20),
        context: context,
      );
      if (isClosed || requestGeneration != _requestGeneration) return;
      emit(
        state.copyWith(
          messages: List.unmodifiable([
            ...conversation,
            AiChatMessage(role: 'assistant', content: reply),
          ]),
          isSending: false,
          clearError: true,
        ),
      );
    } catch (error) {
      if (isClosed || requestGeneration != _requestGeneration) return;
      final message = switch (error) {
        StateError() => error.message.toString(),
        TimeoutException() => 'Asisten belum menjawab. Coba lagi.',
        FormatException() => 'Jawaban tidak dapat dibaca. Coba kirim ulang.',
        _ => 'Asisten tidak dapat menjawab. Periksa koneksi internet dan coba lagi.',
      };
      emit(
        state.copyWith(
          isSending: false,
          error: message.isEmpty
              ? 'Asisten tidak dapat menjawab. Periksa koneksi internet dan coba lagi.'
              : message,
        ),
      );
    }
  }
}
