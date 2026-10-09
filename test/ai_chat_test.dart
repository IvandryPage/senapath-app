import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/assistant/data/ai_chat_gateway.dart';
import 'package:senapath/features/assistant/domain/ai_chat_message.dart';
import 'package:senapath/features/assistant/presentation/ai_chat_cubit.dart';

void main() {
  test('does not send chat data without explicit consent', () async {
    final gateway = _FakeAiChatGateway();
    final cubit = AiChatCubit(gateway);
    addTearDown(cubit.close);

    await cubit.sendMessage(content: 'Strategi?', consent: false);

    expect(gateway.sendCount, 0);
    expect(cubit.state.messages, isEmpty);
    expect(cubit.state.error, contains('Setujui'));
  });

  test(
    'sends opted-in context and appends the real gateway response',
    () async {
      final gateway = _FakeAiChatGateway();
      final cubit = AiChatCubit(gateway);
      addTearDown(cubit.close);

      await cubit.sendMessage(
        content: 'Bagaimana pembagian tenaga?',
        consent: true,
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

  test(
    'does not fake an AI response when the backend is unconfigured',
    () async {
      final gateway = _FakeAiChatGateway(isConfigured: false);
      final cubit = AiChatCubit(gateway);
      addTearDown(cubit.close);

      await cubit.sendMessage(content: 'Halo', consent: true);

      expect(gateway.sendCount, 0);
      expect(cubit.state.messages, isEmpty);
      expect(cubit.state.error, contains('belum dikonfigurasi'));
    },
  );

  test('shows the backend failure message so users can act on it', () async {
    final cubit = AiChatCubit(_FailingAiChatGateway());
    addTearDown(cubit.close);

    await cubit.sendMessage(content: 'Halo', consent: true);

    expect(
      cubit.state.error,
      'Gemini menolak API key. Periksa GEMINI_API_KEY di Supabase.',
    );
    expect(cubit.state.isSending, isFalse);
  });
}

class _FakeAiChatGateway implements AiChatGateway {
  _FakeAiChatGateway({this.isConfigured = true});

  @override
  final bool isConfigured;
  int sendCount = 0;
  Map<String, Object?> lastContext = const {};

  @override
  Future<String> send({
    required List<AiChatMessage> messages,
    required Map<String, Object?> context,
  }) async {
    sendCount++;
    lastContext = context;
    return 'Saran dari Gemini';
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
