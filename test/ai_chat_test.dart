import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/assistant/data/ai_chat_gateway.dart';
import 'package:senapath/features/assistant/domain/ai_chat_message.dart';
import 'package:senapath/features/assistant/presentation/ai_chat_cubit.dart';

void main() {
  test('sends messages directly after the user chooses to send them', () async {
    final gateway = _FakeAiChatGateway();
    final cubit = AiChatCubit(gateway);
    addTearDown(cubit.close);

    await cubit.sendMessage(content: 'Strategi?');

    expect(gateway.sendCount, 1);
    expect(cubit.state.messages, hasLength(2));
    expect(cubit.state.error, isNull);
  });

  test(
    'sends opted-in context and appends the real gateway response',
    () async {
      final gateway = _FakeAiChatGateway();
      final cubit = AiChatCubit(gateway);
      addTearDown(cubit.close);

      await cubit.sendMessage(
        content: 'Bagaimana pembagian tenaga?',
        context: const {
          'route': {'name': 'Loop Utara', 'distanceMeters': 42000},
          'preferences': 'Santai di tanjakan',
        },
      );

      expect(gateway.sendCount, 1);
      expect(gateway.lastContext['route'], isNotNull);
      expect(cubit.state.messages, hasLength(2));
      expect(cubit.state.messages.last.role, 'assistant');
      expect(cubit.state.messages.last.content, 'Saran dari Gemini');
    },
  );

  test('keeps the complete long answer in the chat state', () async {
    final reply = '${'Detail jawaban lengkap. ' * 1200}AKHIR JAWABAN';
    final gateway = _FakeAiChatGateway(reply: reply);
    final cubit = AiChatCubit(gateway);
    addTearDown(cubit.close);

    await cubit.sendMessage(content: 'Jelaskan dengan rinci');

    expect(cubit.state.messages.last.content, reply);
    expect(cubit.state.messages.last.content, endsWith('AKHIR JAWABAN'));
  });

  test(
    'does not fake an AI response when the backend is unconfigured',
    () async {
      final gateway = _FakeAiChatGateway(isConfigured: false);
      final cubit = AiChatCubit(gateway);
      addTearDown(cubit.close);

      await cubit.sendMessage(content: 'Halo');

      expect(gateway.sendCount, 0);
      expect(cubit.state.messages, isEmpty);
      expect(cubit.state.error, contains('belum dikonfigurasi'));
    },
  );

  test('shows the backend failure message so users can act on it', () async {
    final cubit = AiChatCubit(_FailingAiChatGateway());
    addTearDown(cubit.close);

    await cubit.sendMessage(content: 'Halo');

    expect(
      cubit.state.error,
      'Gemini menolak API key. Periksa GEMINI_API_KEY di Supabase.',
    );
    expect(cubit.state.isSending, isFalse);
  });
}

class _FakeAiChatGateway implements AiChatGateway {
  _FakeAiChatGateway({
    this.isConfigured = true,
    this.reply = 'Saran dari Gemini',
  });

  @override
  final bool isConfigured;
  final String reply;
  int sendCount = 0;
  Map<String, Object?> lastContext = const {};

  @override
  Future<String> send({
    required List<AiChatMessage> messages,
    required Map<String, Object?> context,
  }) async {
    sendCount++;
    lastContext = context;
    return reply;
  }
}

class _FailingAiChatGateway implements AiChatGateway {
  @override
  bool get isConfigured => true;

  @override
  Future<String> send({
    required List<AiChatMessage> messages,
    required Map<String, Object?> context,
  }) async {
    throw StateError(
      'Gemini menolak API key. Periksa GEMINI_API_KEY di Supabase.',
    );
  }
}
